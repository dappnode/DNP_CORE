#!/bin/sh

# Upgrade from 0.2.75 to 0.2.76

# Install Debian unattended-upgrades if not installed and enable it
# This script might be executed in Ubuntu, Debian, or Raspbian

# Check if unattended-upgrades is installed
dpkg -s unattended-upgrades &> /dev/null
if [ $? -ne 0 ]; then
    # Install unattended-upgrades
    apt update
    apt install -y unattended-upgrades
fi

# Modifies a config file
modify_config_file() {
    local config_file="$1"
    local config_setting_key="$2"
    local config_setting_value="$3"
    # Remove any appearances of the key from the file
    sed -i "/^$config_setting_key .*/d" "$config_file"
    # Add the updated setting
    echo "$config_setting_key \"$config_setting_value\";" >> "$config_file"
    echo "Modified setting $config_setting_key in $config_file"
}

# Check and configure unattended-upgrades config file
unattended_config_file="/etc/apt/apt.conf.d/50unattended-upgrades"
if [ ! -f "$unattended_config_file" ]; then
    echo "Error: $unattended_config_file should have been created by the unattended-upgrades package"
    exit 1
fi

echo "Unattended-upgrades config file ($unattended_config_file) exists"

# Enable automatic removal of unused dependencies and disable automatic reboot
modify_config_file "$unattended_config_file" 'Unattended-Upgrade::Remove-Unused-Dependencies' 'true'
modify_config_file "$unattended_config_file" 'Unattended-Upgrade::Automatic-Reboot' 'false'

# Check and configure auto-upgrades config file
auto_upgrades_file="/etc/apt/apt.conf.d/20auto-upgrades"
if [ ! -f "$auto_upgrades_file" ]; then
    # Create the file
    echo "Auto upgrades file ($auto_upgrades_file) does not exist. Creating it..."
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades

    # Check if the file was created
    if [ ! -f "$auto_upgrades_file" ]; then
        echo "Error: $auto_upgrades_file could not be created"
        exit 1
    fi
fi

# Enable automatic updates and unattended-upgrades (file should exist now)
modify_config_file "$auto_upgrades_file" 'APT::Periodic::Update-Package-Lists' '1'
modify_config_file "$auto_upgrades_file" 'APT::Periodic::Unattended-Upgrade' '1'
