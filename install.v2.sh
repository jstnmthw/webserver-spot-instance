#!/bin/bash

# Function to check if the script is run as root
check_root() {
  if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root. Please run as root or use sudo."
    exit 1
  fi
}

# Function to check if the required arguments are provided
check_arguments() {
  if [ -z "$1" ] || [ -z "$2" ] || [ -z "$3" ] || [ -z "$4" ]; then
    echo "Usage: $0 <username> <aws_bucket_name> <aws_region> <server_type>"
    exit 1
  fi
}

# Function to set the package manager and default user
set_package_manager() {
  if command -v yum >/dev/null 2>&1; then
    package_manager="yum"
    default_user="ec2-user"
  elif command -v apt-get >/dev/null 2>&1; then
    package_manager="apt-get"
    default_user="ubuntu"
  else
    echo "No package manager found. Exiting..."
    exit 1
  fi
}

# Function to set the hostname based on server type
set_hostname() {
  local server_type="$1"
  if command -v hostnamectl >/dev/null 2>&1; then
    case "$server_type" in
      1) hostnamectl set-hostname webserver ;;
      2|3) hostnamectl set-hostname gameserver ;;
      *) hostnamectl set-hostname server ;;
    esac
  else
    echo "No hostnamectl command found. Skipping..."
  fi
}

# Function to update and install necessary packages
update_and_install_packages() {
  $package_manager update -y
  $package_manager install docker.io git iftop fail2ban -y
  service docker start
  snap install aws-cli --classic
  if [ "$server_type" == "2" ] || [ "$server_type" == "3" ]; then
    $package_manager install make -y
  fi
}

# Function to add a user to the docker group
add_user_to_docker_group() {
  local user="$1"
  usermod -aG docker "$user"
}

# Function to customize the shell prompt for a user
customize_shell_prompt() {
  local user_home="$1"
  echo 'PS1="\[\033[38;5;48m\]\u\[\033[38;5;42m\]@\[\033[38;5;36m\]\h\[\033[38;5;29m\]:\[\033[38;5;30m\]\w \[\033[0m\]\$ "' >> "$user_home/.bashrc"
}

# Function to create a new user if it doesn't exist
create_user() {
  local username="$1"
  if id "$username" >/dev/null 2>&1; then
    echo "User '$username' already exists. Skipping..."
  else
    useradd -m -s /bin/bash "$username"
    add_user_to_docker_group "$username"
    mkdir -p /home/"$username"/.ssh
    cp /home/"$default_user"/.ssh/authorized_keys /home/"$username"/.ssh/
    chown -R "$username":"$username" /home/"$username"/.ssh
    usermod -aG sudo "$username"
    cp /etc/skel/.bashrc /home/"$username"/.bashrc
    echo "${username} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"$username"
    customize_shell_prompt "/home/$username"
  fi
}

# Function to install Docker Compose
install_docker_compose() {
  local docker_compose_version
  docker_compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
  curl --retry 3 --retry-delay 5 -L "https://github.com/docker/compose/releases/download/${docker_compose_version}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  chmod +x /usr/local/bin/docker-compose
}

# Function to associate an Elastic IP with the instance
associate_elastic_ip() {
  aws configure set default.region "$aws_region"
  aws_elastic_ip=$(aws s3 cp s3://${aws_bucket_name}/elastic-ip.txt - | tr -d '\r')
  aws_token=$(curl --silent --request PUT "http://169.254.169.254/latest/api/token" --header "X-aws-ec2-metadata-token-ttl-seconds: 3600")
  aws_instance_id=$(curl --silent "http://169.254.169.254/latest/meta-data/instance-id" --header "X-aws-ec2-metadata-token: $aws_token")
  aws ec2 associate-address --instance-id "$aws_instance_id" --public-ip "$aws_elastic_ip"
}

# Function to set up UFW firewall rules
setup_firewall() {
  ufw default allow outgoing
  ufw default deny incoming
  ufw allow 666/tcp
  ufw allow 80/tcp
  ufw allow 443/tcp
  if [ "$server_type" == "2" ] || [ "$server_type" == "3" ]; then
    ufw allow 27015:27030/udp
    ufw allow 27015:27030/tcp
  fi
  ufw --force enable
}

# Function to set up Fail2Ban
setup_fail2ban() {
  cp /etc/fail2ban/jail.conf /etc/fail2ban/jail.local
  sed -i 's/bantime  = 10m/bantime = 1h/g' /etc/fail2ban/jail.local
  sed -i 's/findtime  = 10m/findtime = 1h/g' /etc/fail2ban/jail.local
  sed -i 's/maxretry = 5/maxretry = 3/g' /etc/fail2ban/jail.local
  systemctl enable fail2ban
  systemctl start fail2ban
}

# Function to install a custom MOTD
install_custom_motd() {
  chmod -x /etc/update-motd.d/*
  rm /etc/update-motd.d/*landscape*
  chmod +x /etc/update-motd.d/*updates-available
  chmod +x /etc/update-motd.d/*reboot-required
  echo "Setting up the MOTD..."
  curl -s https://raw.githubusercontent.com/jstnmthw/webserver-spot-instance/master/motd.sh > /tmp/motd.sh
  chmod +x /tmp/motd.sh
  mv /tmp/motd.sh /etc/update-motd.d/00-motd
  echo "Done."
}

# Function to disable ESM update messages
disable_esm_update_motd() {
  echo "Disabling ESM update motd..."
  sed -Ezi.orig \
    -e 's/(def _output_esm_service_status.*?:\n)/\1    return\n/' \
    -e 's/(def _output_esm_package_alert.*?:\n)/\1    return\n/' \
    /usr/lib/update-notifier/apt_check.py
  /usr/lib/update-notifier/update-motd-updates-available --force
  echo "Done."
}

# Function to update MOTD if using yum
update_motd_if_yum() {
  if command -v yum >/dev/null 2>&1; then
    update-motd
  fi
}

# Function to set up the gameserver
setup_gameserver() {
  if [ "$server_type" == "2" ] || [ "$server_type" == "3" ]; then
    echo "Downloading gameserver setup script..."
    curl -s https://raw.githubusercontent.com/jstnmthw/webserver-spot-instance/master/gameserver.sh > /tmp/gameserver.sh
    chmod +x /tmp/gameserver.sh
    cd /tmp || exit
    ./gameserver.sh "$username"
    echo "Done."
  fi
}

# Function to configure SSHD
configure_sshd() {
  sed -i 's/#Port 22/Port 666/g' /etc/ssh/sshd_config
  systemctl enable ssh
  systemctl restart ssh
}

# Function to upgrade packages and reboot
upgrade_and_reboot() {
  $package_manager upgrade -y && reboot
}

# Checks
check_root
check_arguments "$@"

# Assign variables
username="$1"
aws_bucket_name="$2"
aws_region="$3"
server_type="$4"
default_user="root"

# Main script executions
set_package_manager
set_hostname "$server_type"
update_and_install_packages
add_user_to_docker_group "$default_user"
customize_shell_prompt "/home/$default_user"
create_user "$username"
install_docker_compose
associate_elastic_ip
setup_firewall
setup_fail2ban
install_custom_motd
disable_esm_update_motd
update_motd_if_yum
setup_gameserver
configure_sshd
upgrade_and_reboot
