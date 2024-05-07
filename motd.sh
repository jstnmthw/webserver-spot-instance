#!/bin/bash

# Color codes
red="\033[38;5;203m"
yellow="\033[38;5;154m"
green="\033[38;5;83m"
orange="\033[38;5;209m"
lime="\033[38;5;48m"
blue="\033[1;34m"
purple="\033[1;35m"
violet="\033[0;35m"
cyan="\033[1;36m"
white="\033[1;37m"
bold="\033[1m"
dark_grey="\033[1;30m"

# Reset color
reset_color="\033[0m"

# Detect apt or yum
if [ -n "$(command -v yum)" ]; then
  package_manager="yum"
elif [ -n "$(command -v apt-get)" ]; then
  package_manager="apt-get"
else
  echo "No package manager found. Exiting..."
  exit 1;
fi

# Display the OS
get_os() {
  os=$(cat /etc/os-release | grep PRETTY_NAME | cut -d "=" -f 2- | sed 's/"//g')
  printf "${dark_grey}Welcome to $os \033[0m\n"
}

# Display the ASCII header
get_ascii_header() {
  printf "%b\n" \
  "\033[38;5;128m __\033[38;5;129m___\033[38;5;93m___\033[38;5;99m    \033[38;5;63m   \033[38;5;69m  _\033[38;5;33m_   \033[38;5;39m  _\033[38;5;38m___\033[38;5;44m___ \033[38;5;43m   \033[38;5;49m   \033[38;5;48m    \033[38;5;84m   \033[38;5;83m   \033[38;5;119m    \033[38;5;118m   \033[38;5;154m   \033[38;5;148m   " \
  "\033[38;5;128m|  \033[38;5;129m|  \033[38;5;93m|  \033[38;5;99m|.-\033[38;5;63m----\033[38;5;69m.| \033[38;5;33m |--\033[38;5;39m.| \033[38;5;38m   \033[38;5;44m __\033[38;5;43m|.--\033[38;5;49m---\033[38;5;48m.--\033[38;5;84m--.-\033[38;5;83m-.-\033[38;5;119m-.--\033[38;5;118m---\033[38;5;154m.--\033[38;5;148m--." \
  "\033[38;5;128m| \033[38;5;129m |  \033[38;5;93m|  \033[38;5;99m|| \033[38;5;63m -_\033[38;5;69m_|| \033[38;5;33m _ \033[38;5;39m ||\033[38;5;38m__  \033[38;5;44m   \033[38;5;43m||  \033[38;5;49m-__\033[38;5;48m|  \033[38;5;84m _| \033[38;5;83m | \033[38;5;119m | \033[38;5;118m -_\033[38;5;154m_|  \033[38;5;148m _|" \
  "\033[38;5;128m|_\033[38;5;129m___\033[38;5;93m___\033[38;5;99m_||_\033[38;5;63m___\033[38;5;69m_||\033[38;5;33m____\033[38;5;39m_||\033[38;5;38m___\033[38;5;44m____\033[38;5;43m||_\033[38;5;49m___\033[38;5;48m_|__\033[38;5;84m|  \033[38;5;83m\__\033[38;5;119m_/|_\033[38;5;118m___\033[38;5;154m_|_\033[38;5;148m_|  " \
  "\033[0m"
}

# Display the uptime
get_uptime() {
  uptime=$(uptime -p | sed -e 's/up //g')
  printf "up $uptime\n\n"
}

# Calculate the CPU usage
get_cpu_usage() {
  cpu_usage=$(top -b -n1 | grep "%Cpu(s)" | awk '{print $2}')
  printf "CPU Usage.....: $cpu_usage%%\n"
}

# Check for updates
get_check_updates() {
  # Update the package database
  sudo $package_manager check-update > /dev/null 2>&1

  # Check for all updates
  all_updates=$(sudo $package_manager check-update 2>/dev/null | tail -n +4 | wc -l)
  if [ "$all_updates" -gt 0 ]; then
    printf "$all_updates packages can be updated.\n"

    # Check for security updates
    security_updates=$(sudo $package_manager --security check-update 2>/dev/null | wc -l)
    printf "$security_updates are security updates. \n"
    printf "\n\n"
  fi
}

# Check for needed reboots
get_check_reboot() {
  reboot_needed=$(sudo $package_manager needs-restarting 2>/dev/null | wc -l)
  if [ "$reboot_needed" -gt 0 ]; then
    printf "**** System restart required ****\n\n"
  fi
}

# Retrieve RAM usage and total RAM
get_ram_usage() {
  ram_info=$(free -m | awk '/Mem/ {print $2, $3}')
  read -r total_ram used_ram <<< "$ram_info"

  # Convert RAM usage to GB if needed
  if [ "$used_ram" -gt 1024 ]; then
    used_ram=$(awk "BEGIN {printf \"%.2f\", $used_ram / 1024}")" GB"
  else
    used_ram="$used_ram MB"
  fi

  # Convert total RAM to GB if needed
  if [ "$total_ram" -gt 1024 ]; then
    total_ram=$(awk "BEGIN {printf \"%.2f\", $total_ram / 1024}")" GB"
  else
    total_ram="$total_ram MB"
  fi

  printf "RAM Usage.....: $used_ram / $total_ram\n"
}

# Display a text-based progress bar for disk space
# TODO: Should be a better way to find the main disk drive than ignoring tons of disk names.
get_disk_space() {
  printf "\n%-20s %-10s %-10s %-10s %-10s %-10s\n" "Filesystems" "Size" "Used" "Avail" "Use%" "Mounted"
  df -BG | awk 'NR>1 {print $1, $2, $3, $4, $5, $6}' | grep -vE 'tmpfs|devtmpfs|boot|mnt|run|init|docker' | while read -r filesystem size used avail use mounted; do
    printf "%-20s %-10s %-10s %-10s %-10s %-10s\n" "$filesystem" "$size" "$used" "$avail" "$use" "$mounted"
    used_space=${used%G}
    total_space=${size%G}
    generate_progress_bar "$used_space" "$total_space" 70
  done
}

# Generate a text-based progress bar
generate_progress_bar() {
  current_value=$1
  total_value=$2
  total_blocks=$3

  percentage=$((current_value * 100 / total_value))
  filled_blocks=$((current_value * total_blocks / total_value))
  empty_blocks=$((total_blocks - filled_blocks))

  # Color the blocks according to the percentage
  if [ "$percentage" -lt 75 ]; then
    color_code=$green
  elif [ "$percentage" -lt 90 ]; then
    color_code=$yellow
  else
    color_code=$red
  fi

  # Create the progress bar string with color codes
  printf "["
  printf "${color_code}"
  printf "%0.s=" $(seq 1 $filled_blocks)
  printf "\033[1;30m"
  
  if [ "$filled_blocks" != "$total_blocks" ]; then
    printf "%0.s=" $(seq 1 $empty_blocks)
  fi

  printf "\033[0m]\n\n"
}

# Display the Fail2Ban status
get_fail2ban_status() {
  if [ -n "$(command -v fail2ban-client)" ]; then
    fail2ban_status=$(sudo systemctl is-active fail2ban.service)
    read -r status jail_list <<< "$fail2ban_status"

    # Checks if Fail2Ban is running and change $status color accordingly
    status_txt="${red}$status${reset_color}"
    if [ "$status" = "active" ]; then
      status_txt="${green}$status${reset_color}"
    fi

    printf "Fail2ban......: $status_txt\n"
    if [ "$status" = "active" ]; then
      printf "Ban Count.....: $(sudo fail2ban-client status sshd | grep -oP 'Total banned:\s*\K\d+')\n"
    fi
  else
    printf "Fail2ban......: ${orange}not installed${reset_color}\n"
  fi
}

get_ufw_status() {
  if [ -n "$(command -v ufw)" ]; then
    ufw_status=$(sudo ufw status | grep -oP 'Status:\s*\K\w+')

    # Checks if UFW is running and change $ufw_status color accordingly
    if [ "$ufw_status" = "active" ]; then
      ufw_status="${green}$ufw_status${reset_color}"
    else
      ufw_status="${red}$ufw_status${reset_color}"
    fi

    printf "Firewall......: $ufw_status\n"
  else
    printf "Firewall......: ${red}not installed${reset_color}\n"
  fi
}

# Display the MOTD
clear
get_os
get_ascii_header
get_uptime
get_cpu_usage
get_ram_usage
get_ufw_status
get_fail2ban_status
get_disk_space
