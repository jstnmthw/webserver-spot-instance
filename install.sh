#!/bin/bash

# If arguments 1, 2 & 3 are not provided, exit with a message
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ]; then
  echo "Usage: $0 <username> <aws_bucket_name> <aws_region>"
  exit 1;
fi

# Username
username=$1

# Type (webserver or gameserver)
type=$2

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

# Set the hostname
echo "webserver" > /etc/hostname
hostnamectl set-hostname webserver

# Update the instance
sudo $package_manager update -y

# Install Docker
sudo $package_manager install docker.io -y
sudo service docker start

# Install services
sudo $package_manager install git awscli iftop fail2ban -y

# Install user and add to docker group
useradd -m -s /bin/bash $username
sudo usermod -a -G docker $username

# Copy the SSH public key from the default user to the new user
mkdir -p /home/$username/.ssh
cp /home/$default_user/.ssh/authorized_keys /home/$username/.ssh/
chown -R $username:$username /home/$username/.ssh

# Add the new user to the sudoers group (optional, for administrative privileges)
usermod -aG sudo $username
cp /etc/skel/.bashrc /home/$username/.bashrc
echo "${username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$username

# Customize the shell prompt to display the username and hostname
echo 'PS1="\u@\h:\w\$ "' >> /home/$username/.bashrc

# Restart the SSH service for changes to take effect
sed -i 's/#Port 22/Port 666/g' /etc/ssh/sshd_config
systemctl restart ssh

# Install docker-compose
docker_compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Associate Elastic IP
aws configure set default.region $3
aws_bucket_url=$2
aws_elastic_ip=$(aws s3 cp s3://${aws_bucket_url}/elastic-ip.txt - | tr -d '\r')
aws_token=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
aws_instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id --header "X-aws-ec2-metadata-token: $aws_token")
aws ec2 associate-address --instance-id $aws_instance_id --public-ip $aws_elastic_ip

# Generate a new SSH key pair
ssh-keygen -t rsa -b 4096 -C "webserver" -f /home/$username/.ssh/id_rsa -N ""
eval "$(ssh-agent -s)"
ssh-add /home/$username/.ssh/id_rsa

# Setup ufw firewall with deny rules and then allow rules
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow 666
sudo ufw allow http
sudo ufw allow https
sudo ufw --force enable

# If gameserver open port 27015-27030
if [ "$type" == "gameserver" ]; then
  sudo ufw allow 27015:27030/udp
  sudo ufw allow 27015:27030/tcp
  sudo apt-get install make -y
fi

# Setup fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/bantime = 10m/bantime = 1h/g' /etc/fail2ban/jail.local
sudo sed -i 's/findtime = 10m/findtime = 1h/g' /etc/fail2ban/jail.local
sudo sed -i 's/maxretry = 5/maxretry = 3/g' /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Download and install custom motd from the repo and copy it to /etc/update-motd.d/00-motd
sudo chmod -x /etc/update-motd.d/*
sudo rm /etc/update-motd.d/*landscape*
sudo chmod +x /etc/update-motd.d/*updates-available
sudo chmod +x /etc/update-motd.d/*reboot-required

curl -s https://raw.githubusercontent.com/jstnmthw/webserver-spot-instance/master/motd.sh > /tmp/motd.sh
chmod +x /tmp/motd.sh
sudo mv /tmp/motd.sh /etc/update-motd.d/00-motd

if [ -n "$(command -v yum)" ]; then  
  sudo update-motd
fi

# Execute git script
sudo ./git.sh $username