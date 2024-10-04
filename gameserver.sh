#!/bin/bash

# If arguments 1 exit with a message
if [ -z "$1" ]; then
  echo "Usage: $0 <username>"
  exit 1;
fi

# Username
username=$1

su - $username -c "git clone https://github.com/jstnmthw/srcds-autoinstall.git /home/$username/srcds-autoinstall"

su - $Username

cd /home/$username/srcds-autoinstall
touch .env

make install SCRIPT=cs2-example
