#!/bin/bash

# Enable IP forwarding for NAT
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.ens5.send_redirects=0
iptables -t nat -A POSTROUTING -o ens5 -j MASQUERADE

# Persist the NAT settings across reboots
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.ens5.send_redirects=0" >> /etc/sysctl.conf

# Update the package lists for upgrades and new package installations
apt-get update
apt-get upgrade -y

# Preseed the answers for iptables-persistent package
echo "iptables-persistent iptables-persistent/autosave_v4 boolean true" | debconf-set-selections
echo "iptables-persistent iptables-persistent/autosave_v6 boolean true" | debconf-set-selections

# Install iptables-persistent and save rules
apt-get install -y iptables-persistent

# Save the current rules
iptables-save > /etc/iptables/rules.v4

# Enable and start the netfilter-persistent service
systemctl enable netfilter-persistent
systemctl start netfilter-persistent

# Install Docker
apt-get install -y docker.io

# Add the current user to the docker group to allow executing docker commands without sudo
usermod -aG docker ubuntu

# Install development-related packages
apt-get install -y python3 python3-pip jq redis-tools unzip git wget net-tools

# Install Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p /opt/miniconda
rm /tmp/miniconda.sh

# Nodejs
curl -sL https://deb.nodesource.com/setup_18.x -o nodesource_setup.sh
bash nodesource_setup.sh
sudo apt install nodejs npm

# Tools
sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt $(lsb_release -cs)-pgdg main" > /etc/apt/sources.list.d/pgdg.list'
wget --quiet -O - https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add -
apt-get update -y
apt-get install postgresql-client-14 -y

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Get the instance ID using IMDSv2 and disable Source/Destination check
TOKEN=$(curl -X PUT "http://169.254.169.254/latest/api/token" -H "X-aws-ec2-metadata-token-ttl-seconds: 21600")
INSTANCE_ID=$(curl -H "X-aws-ec2-metadata-token: $TOKEN" -v http://169.254.169.254/latest/meta-data/instance-id)
aws ec2 modify-instance-attribute --instance-id $INSTANCE_ID --no-source-dest-check

# Set hostname
hostnamectl set-hostname admin-bastion

# Get users and admins comma separated list
export PARAM_USER_PATH="/config/infra-admin-bastion/user-list"
export PARAM_ADMIN_PATH="/config/infra-admin-bastion/admin-list"

export USER_LIST=$(aws ssm get-parameters --names "$PARAM_USER_PATH" --with-decryption --query "Parameters[*].{Value:Value}" --output text)
export ADMIN_LIST=$(aws ssm get-parameters --names "$PARAM_ADMIN_PATH" --with-decryption --query "Parameters[*].{Value:Value}" --output text)

# Convert list to array and add users
IFS=',' read -ra user_array <<< "$USER_LIST"
for user in "${user_array[@]}"; do
  useradd -m $user -s /usr/bin/bash
  passwd -d $user
  mkdir /home/$user/.ssh
  aws ssm get-parameters --names "/config/infra-admin-bastion/authorized-keys/$user" \
  --with-decryption --query "Parameters[*].{Value:Value}" \
  --output text > /home/$user/.ssh/authorized_keys
  chown $user:$user /home/$user/.ssh
  chmod 700 /home/$user/.ssh
  chmod 600 /home/$user/.ssh/authorized_keys
  chown $user:$user /home/$user/.ssh/authorized_keys
  usermod -aG docker $user
  # Add Miniconda to PATH for the ubuntu user
  echo 'export PATH="/opt/miniconda/bin:$PATH"' >> /home/$user/.bashrc
done

# Add sudo privileges to admins
IFS=',' read -ra admin_array <<< "$ADMIN_LIST"
for admin in "${admin_array[@]}"; do
  usermod -aG sudo $admin
done

# Cleanup
userdel -fr ubuntu 2>/dev/null

# SystemD enable and start docker service
systemctl enable --now docker

# Reboot
reboot now
