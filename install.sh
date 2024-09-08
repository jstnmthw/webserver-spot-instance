#!/bin/bash

# If arguments 1, 2 & 3 are not provided, exit with a message
if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
  echo "Usage: $0 <username> <aws_bucket_name> <aws_region> <server_type>"
  exit 1;
fi

# Username
username=$1

# AWS bucket name
aws_bucket_name=$2

# AWS region
aws_region=$3

# Type - webserver, gameserver or both
server_type=$4

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
if [ -n "$(command -v hostnamectl)" ]; then
  if [ "$server_type" == 1 ]; then
    sudo hostnamectl set-hostname webserver
  elif [ "$server_type" == 2 ] || [ "$server_type" == 3 ]; then
    sudo hostnamectl set-hostname gameserver
  else
    sudo hostnamectl set-hostname server
  fi
else
  echo "No hostnamectl command found. Skipping..."
fi

# Update the instance
sudo $package_manager update -y

# Install Docker
sudo $package_manager install docker.io -y
sudo service docker start

# Install services
sudo $package_manager install git iftop fail2ban -y

# Install AWS CLI
sudo snap install aws-cli --classic

if [ "$sever_type" == 2 ] || [ "$server_type" == 3 ]; then
  sudo $package_manager install make -y
fi

# Check if user exists, if not create it, copy SSH key and add to docker group
if id "$username" >/dev/null 2>&1; then
  echo "User already exists. Skipping..."
else
  # Install user and add to docker group
  useradd -m -s /bin/bash $username
  sudo usermod -a -G docker $username

  # Copy the SSH authorized key from the default user to the newly created user
  mkdir -p /home/$username/.ssh
  cp /home/$default_user/.ssh/authorized_keys /home/$username/.ssh/
  chown -R $username:$username /home/$username/.ssh

  # Add the new user to the sudoers group (optional, for administrative privileges)
  usermod -aG sudo $username
  cp /etc/skel/.bashrc /home/$username/.bashrc
  echo "${username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/$username

  # Customize the shell prompt to display the username and hostname
  # Using neon green to violet gradient for the username and hostname
  echo "PS1=\"\[\033[1;30m\]\u\[\033[38;5;83m\]@\[\033[1;30m\]\h\[\033[1;30m\]:\[\033[38;5;83m\]\w\[\033[38;5;83m\] \\$ \[\033[0m\]\"" >> /home/$username/.bashrc
fi

# Install docker-compose
docker_compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
sudo curl -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Setup ufw firewall with deny rules and then allow rules
sudo ufw default allow outgoing
sudo ufw default deny incoming

sudo ufw allow 666/tcp
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# If gameserver open srcds ports 27015-27030
if [ "$sever_type" == 2 ] || [ "$server_type" == 3 ]; then
  sudo ufw allow 27015:27030/udp
  sudo ufw allow 27015:27030/tcp
fi

# Enable firewall
sudo ufw enable

# Setup fail2ban
sudo cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
sudo sed -i 's/bantime = 12h/bantime = 1h/g' /etc/fail2ban/jail.local
sudo sed -i 's/findtime = 1m/findtime = 1h/g' /etc/fail2ban/jail.local
sudo sed -i 's/maxretry = 3/maxretry = 3/g' /etc/fail2ban/jail.local
sudo systemctl enable fail2ban
sudo systemctl start fail2ban

# Download and install custom motd from the repo and copy it to /etc/update-motd.d/00-motd
sudo chmod -x /etc/update-motd.d/*
sudo rm /etc/update-motd.d/*landscape*
sudo chmod +x /etc/update-motd.d/*updates-available
sudo chmod +x /etc/update-motd.d/*reboot-required

echo "Setting up the MOTD..."
curl -s https://raw.githubusercontent.com/jstnmthw/webserver-spot-instance/master/motd.sh > /tmp/motd.sh
chmod +x /tmp/motd.sh
sudo mv /tmp/motd.sh /etc/update-motd.d/00-motd
echo "Done."

echo "Disabling ESM update motd..."
sudo sed -Ezi.orig \
  -e 's/(def _output_esm_service_status.outstream, have_esm_service, service_type.:\n)/\1    return\n/' \
  -e 's/(def _output_esm_package_alert.*?\n.*?\n.:\n)/\1    return\n/' \
  /usr/lib/update-notifier/apt_check.py
sudo /usr/lib/update-notifier/update-motd-updates-available --force
echo "Done."

if [ -n "$(command -v yum)" ]; then  
  sudo update-motd
fi

# Execute webserver setup script
# if [ "$sever_type" == 1 ]; then
  # TODO: Implement webserver setup script
  # sudo ./site.sh $username
# fi

# Execute gameserver setup script
if [ "$sever_type" == 2 ] || [ "$server_type" == 3 ]; then
  echo "Downloading gameserver setup script..."
  curl -s https://raw.githubusercontent.com/jstnmthw/webserver-spot-instance/master/gameserver.sh > /tmp/gameserver.sh
  echo "Done."
  chmod +x /tmp/gameserver.sh
  sudo ./tmp/gameserver.sh
fi

# Set sshd to listen on port 666
sed -i 's/#Port 22/Port 666/g' /etc/ssh/sshd_config

# Wait for SSH service to be fully up
while ! systemctl is-active --quiet ssh; do
    echo "Waiting for SSH service to be active..."
    sleep 1
done

sudo systemctl enable ssh
sudo systemctl restart ssh

# Associate Elastic IP
aws configure set default.region $aws_region
aws_elastic_ip=$(aws s3 cp s3://${aws_bucket_name}/elastic-ip.txt - | tr -d '\r')
aws_token=$(curl --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
aws_instance_id=$(curl -s http://169.254.169.254/latest/meta-data/instance-id --header "X-aws-ec2-metadata-token: $aws_token")
aws ec2 associate-address --instance-id $aws_instance_id --public-ip $aws_elastic_ip