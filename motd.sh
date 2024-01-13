#!/bin/bash

# Color codes
red="\033[0;31m"
yellow="\033[0;33m"
green="\033[1;32m"
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
  printf "${dark_grey}Welcome to $os [0m\n"
}

# Display the ASCII header
get_ascii_header() {
  printf "%b\n" \
  "[38;5;128m __[38;5;129m___[38;5;93m___[38;5;99m    [38;5;63m   [38;5;69m  _[38;5;33m_   [38;5;39m  _[38;5;38m___[38;5;44m___ [38;5;43m   [38;5;49m   [38;5;48m    [38;5;84m   [38;5;83m   [38;5;119m    [38;5;118m   [38;5;154m   [38;5;148m   " \
  "[38;5;128m|  [38;5;129m|  [38;5;93m|  [38;5;99m|.-[38;5;63m----[38;5;69m.| [38;5;33m |--[38;5;39m.| [38;5;38m   [38;5;44m __[38;5;43m|.--[38;5;49m---[38;5;48m.--[38;5;84m--.-[38;5;83m-.-[38;5;119m-.--[38;5;118m---[38;5;154m.--[38;5;148m--." \
  "[38;5;128m| [38;5;129m |  [38;5;93m|  [38;5;99m|| [38;5;63m -_[38;5;69m_|| [38;5;33m _ [38;5;39m ||[38;5;38m__  [38;5;44m   [38;5;43m||  [38;5;49m-__[38;5;48m|  [38;5;84m _| [38;5;83m | [38;5;119m | [38;5;118m -_[38;5;154m_|  [38;5;148m _|" \
  "[38;5;128m|_[38;5;129m___[38;5;93m___[38;5;99m_||_[38;5;63m___[38;5;69m_||[38;5;33m____[38;5;39m_||[38;5;38m___[38;5;44m____[38;5;43m||_[38;5;49m___[38;5;48m_|__[38;5;84m|  [38;5;83m\__[38;5;119m_/|_[38;5;118m___[38;5;154m_|_[38;5;148m_|  " \
  "[0m"
}

# Display the uptime
get_uptime() {
  uptime=$(uptime -p | sed -e 's/up //g')
  printf "up $uptime\n\n"
}

# Calculate the CPU usage
get_cpu_usage() {
  cpu_usage=$(top -b -n1 | grep "%Cpu(s)" | awk '{print $2}')
  printf "CPU Usage: $cpu_usage%%\n"
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
  printf "RAM Usage: $used_ram MB / $total_ram MB\n"
}

# Display a text-based progress bar for disk space
get_disk_space() {
  printf "\n%-20s %-10s %-10s %-10s %-10s %-10s\n" "Filesystems" "Size" "Used" "Avail" "Use%" "Mounted"
  df -BG | awk 'NR>1 {print $1, $2, $3, $4, $5, $6}' | grep -vE 'tmpfs|devtmpfs|boot|mnt|run|init' | while read -r filesystem size used avail use mounted; do
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

  # Check percentage, if under 50% set color to green, 
  # if under 75% set color to yellow, 
  # else set color to red.
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

get_fail2ban_status() {
  fail2ban_status=$(systemctl status fail2ban | grep Active | awk '{print $2}')
  if [ "$fail2ban_status" == "active" ]; then
    printf "Fail2ban: ${color}Online${reset_color}\n"
  else
    printf "Fail2ban: ${color}Offline${reset_color}\n"
  fi
}

get_fail2ban_count() {
  fail2ban_count=$(fail2ban-client status | grep "Number of jail:" | awk '{print $5}')
  printf "IP's jailed: ${green}$fail2ban_count${reset_color}\n"
}

# Display the MOTD
clear
get_os
get_ascii_header
get_uptime
get_cpu_usage
get_ram_usage
get_fail2ban_status
get_fail2ban_count
get_disk_space
# get_check_updates
# get_check_reboot
