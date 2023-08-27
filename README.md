# Infra-Admin-NAT-Instance

## Overview

This repository contains a user data script for automatically setting up an Admin NAT (Network Address Translation) instance on AWS. The instance is configured to act as a NAT for private subnets, and it also installs various utilities like Docker, AWS CLI, Node.js, and PostgreSQL client, among others.

## Features

- Enables and configures IP forwarding for NAT
- Updates and installs essential packages
- Installs and configures iptables for NAT
- Installs Docker
- Installs Miniconda, Node.js, and PostgreSQL client
- Configures AWS CLI v2
- Retrieves instance metadata to disable source/destination checks
- Fetches user and admin data from AWS SSM Parameter Store
- Adds users and admins to the system
- Gives sudo privileges to admin users
- Enables and starts essential services

## Prerequisites

- AWS Account
- EC2 instance with Amazon Linux 2 or a similar Linux distribution
- IAM role attached to the instance with the necessary permissions

## IAM Role Permissions

The EC2 instance needs to be launched with an IAM role that has the following permissions:

- `ec2:ModifyInstanceAttribute` (for modifying instance attributes like source/dest check)
- `ssm:GetParameters` (for fetching user and admin lists and SSH keys from SSM)

Example IAM policy:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "EC2Permissions",
            "Effect": "Allow",
            "Action": [
                "ec2:ModifyInstanceAttribute"
            ],
            "Resource": "*"
        },
        {
            "Sid": "SSMPermissions",
            "Effect": "Allow",
            "Action": [
                "ssm:GetParameters"
            ],
            "Resource": "*"
        }
    ]
}
```

> **Note**: For production use, restrict the resource scope and use condition keys for better security.

## Important Notes

- It's crucial to disable source/destination checks on the instance for NAT functionality.
- Using a launch template is highly recommended for standardizing instance configurations.
- Make sure to add this instance as the target in your route tables for each private subnet with a destination of `0.0.0.0/0` to enable NAT.

## Usage

1. Launch an AWS EC2 instance and attach the IAM role with the required permissions.
2. In the instance launch configuration, provide the script as the user data.
3. Start the instance.

The user data script will configure the instance automatically.

## Contributing

Feel free to open issues and pull requests for additional features and bug fixes.
