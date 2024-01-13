#!/bin/bash

# Display the ASCII header
get_ascii_header() {
  printf "${green} ________         __     _______                              \n"
  printf "${green}|  |  |  |.-----.|  |--.|     __|.-----.----.--.--.-----.----.\n"
  printf "${green}|  |  |  ||  -__||  _  ||__     ||  -__|   _|  |  |  -__|   _|\n"
  printf "${green}|________||_____||_____||_______||_____|__|  \___/|_____|__|  \n\n"
  printf "${reset_color}"
}

# While loop with sleep that called get_ascii_header_gradient
while true; do
  get_ascii_header | lolcat
  sleep 0.05
  clear
done