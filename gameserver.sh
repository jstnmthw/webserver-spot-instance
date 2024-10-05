#!/bin/bash

# If argument 1 is missing, exit with a message
if [ -z "$1" ]; then
  echo "Usage: $0 <username>"
  exit 1;
fi

# Username
username=$1

# Set maximum retries and delay for network operations
MAX_RETRIES=3       # Maximum number of retries
RETRY_DELAY=5       # Delay between retries in seconds

# Function to perform git clone with retry logic
clone_repo() {
  ATTEMPT=1
  until su - "$username" -c "git clone https://github.com/jstnmthw/srcds-autoinstall.git /home/$username/srcds-autoinstall"; do
    if [ $ATTEMPT -ge $MAX_RETRIES ]; then
      echo "Error: Failed to clone repository after $ATTEMPT attempts."
      exit 1
    fi
    echo "Warning: git clone failed. Retrying in $RETRY_DELAY seconds..."
    sleep $RETRY_DELAY
    ((ATTEMPT++))
  done
}

# Function to perform make install with retry logic
make_install() {
  ATTEMPT=1
  until make install SCRIPT=cs2-example; do
    if [ $ATTEMPT -ge $MAX_RETRIES ]; then
      echo "Error: make install failed after $ATTEMPT attempts."
      exit 1
    fi
    echo "Warning: make install failed. Retrying in $RETRY_DELAY seconds..."
    sleep $RETRY_DELAY
    ((ATTEMPT++))
  done
}

# Check if the directory already exists
if [ -d "/home/$username/srcds-autoinstall" ]; then
  echo "Info: Directory /home/$username/srcds-autoinstall already exists. Skipping git clone."
else
  # Perform git clone with retries
  clone_repo
fi

# Change to the repository directory
cd /home/$username/srcds-autoinstall || {
  echo "Error: Failed to change directory to /home/$username/srcds-autoinstall"
  exit 1
}

# Create .env file if it doesn't exist
if [ ! -f .env ]; then
  touch .env
fi

# Perform make install with retries
make_install
