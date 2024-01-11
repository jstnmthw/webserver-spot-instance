#!/bin/bash

# Latest version of docker-compose
docker_compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)

# If arguments 1 and 2 are not provided, exit with a message
if [ -z "$1" ] || [ -z "$2" ]; then
  echo "Usage: $0 <username> <aws_bucket_name>"
  exit 1;
fi

# Username
username=$1

# Default user
default_user="root"

# Detect apt or yum
if [ -n "$(command -v yum)" ]; then
  package_manager="yum"
  default_user="ec2-user"
elif [ -n "$(command -v apt-get)" ]; then
  package_manager="apt-get"
  default_user="ubuntu"
else
  echo "No package manager found. Exiting..."
  exit 1;
fi

# Detect wheel or sudo
if [ -n "$(command -v wheel)" ]; then
  admin_type="wheel"
elif [ -n "$(command -v sudo)" ]; then
  admin_type="sudo"
else
  echo "No sudo or wheel found. Exiting..."
  exit 1;
fi

# Set the hostname
echo "webserver" > /etc/hostname
hostnamectl set-hostname webserver

# Update the instance
sudo $package_manager update -y

# Install Docker
sudo $package_manager install docker -y
sudo service docker start

# Install services
sudo $package_manager install git awscli iftop -y

# Install user and add to docker group
useradd -m -s /bin/bash $username
sudo usermod -a -G docker $username

# Copy the SSH public key from the default user to the new user
mkdir -p /home/$username/.ssh
cp /home/$default_user/.ssh/authorized_keys /home/$username/.ssh/
chown -R $username:$username /home/$username/.ssh

# Add the new user to the sudoers group (optional, for administrative privileges)
usermod -aG $admin_type $username
echo '$username ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$username

# Customize the shell prompt to display the username and hostname
echo 'PS1="\u@\h:\w\$ "' >> /home/$username/.bashrc

# Restart the SSH service for changes to take effect
systemctl restart ssh

# Install docker-compose
sudo curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Associate Elastic IP
aws_default_region=$(aws configure get region)
aws_bucket_url=$2 # s3://bucket-name
aws_elastic_ip=$(aws s3 cp s3://${aws_bucket_url}/elastic-ip.txt - | tr -d '\r')
aws_token=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
aws_instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id --header "X-aws-ec2-metadata-token: $aws_token")

aws ec2 associate-address --instance-id $aws_instance_id --public-ip $aws_elastic_ip
