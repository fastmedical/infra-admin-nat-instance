#!/bin/bash

# Enable IP forwarding for NAT
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv4.conf.eth0.send_redirects=0
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# Persist the NAT settings across reboots
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
echo "net.ipv4.conf.eth0.send_redirects=0" >> /etc/sysctl.conf
echo "iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE" >> /etc/rc.local

# Update the package lists for upgrades and new package installations
apt-get update
apt-get upgrade -y

# Install Docker
apt-get install -y docker.io

# Add the current user to the docker group to allow executing docker commands without sudo
usermod -aG docker ubuntu

# Install development-related packages
apt-get install -y python3 python3-pip nodejs npm jq redis-tools unzip git wget

# Install Miniconda
wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-aarch64.sh -O /tmp/miniconda.sh
bash /tmp/miniconda.sh -b -p /opt/miniconda
rm /tmp/miniconda.sh

# Add Miniconda to PATH for the ubuntu user
echo 'export PATH="/opt/miniconda/bin:$PATH"' >> /home/ubuntu/.bashrc
source /home/ubuntu/.bashrc

# Initialize conda for bash shell (this makes conda activate command available)
/opt/miniconda/bin/conda init bash

# Install AWS CLI v2
curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install

# Set hostname
hostnamectl set-hostname devel-bastion

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
done

# Add sudo privileges to admins
IFS=',' read -ra admin_array <<< "$ADMIN_LIST"
for admin in "${admin_array[@]}"; do
  usermod -aG sudo $admin
done

# SystemD enable and start docker service
systemctl enable --now docker
