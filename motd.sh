#!/bin/bash

# Color codes
red="\033[0;31m"
yellow="\033[1;33m"
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
  printf "${dark_grey}Welcome to $os\n"
}

# Display the ASCII header
get_ascii_header() {
  printf "${green} ________         __     _______                              \n"
  printf "${green}|  |  |  |.-----.|  |--.|     __|.-----.----.--.--.-----.----.\n"
  printf "${green}|  |  |  ||  -__||  _  ||__     ||  -__|   _|  |  |  -__|   _|\n"
  printf "${green}|________||_____||_____||_______||_____|__|  \___/|_____|__|  \n\n"
  printf "${reset_color}"
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
  df -BG | awk 'NR>1 {print $1, $2, $3, $4, $5, $6}' | grep -vE 'tmpfs|devtmpfs|nvme0n1p128' | while read -r filesystem size used avail use mounted; do
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
  if [ "$percentage" -lt 50 ]; then
    color_code="\033[0;32m"
  elif [ "$percentage" -lt 75 ]; then
    color_code="\033[1;33m"
  else
    color_code="\033[0;31m"
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

# Display the MOTD
clear
get_os
get_ascii_header
get_uptime
get_cpu_usage
get_ram_usage
get_disk_space
get_check_updates
get_check_reboot