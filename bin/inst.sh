#!/bin/bash

# Check if at least one package and an optional comment/category are provided
if [ "$#" -lt 1 ]; then
  echo "Usage: $0 <package(s)> [category/comment]"
  exit 1
fi

# Log file location
LOG_FILE="$root/home/morgen/Documents/Logging/Installs/systemlog.txt"
USER_LOG_FILE="$HOME/Documents/Logging/Installs/userlog.txt"

# Get the package(s) to install
PACKAGES="$1"
shift # Shift arguments to get the category/tag (if any)

# Join the remaining arguments as a category/comment
CATEGORY="$@"

# Date and time format for logging
TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")

# Check if installing system-wide (sudo) or user-specific
if [ "$(whoami)" == "root" ]; then
    INSTALL_TYPE="sudo"
else
    INSTALL_TYPE="user"
fi

# Run the installation command
if [ "$INSTALL_TYPE" == "sudo" ]; then
    sudo apt install -y $PACKAGES
    echo "$TIMESTAMP : sudo apt install : $PACKAGES : $CATEGORY" >> "$LOG_FILE"
else
    echo "User install: $PACKAGES"
    echo "$TIMESTAMP : user install : $PACKAGES : $CATEGORY" >> "$USER_LOG_FILE"
fi

echo "Package(s) installed and logged successfully."
