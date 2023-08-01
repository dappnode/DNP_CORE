# Install Debian unattended-upgrades if not installed and enable it
# Reference: https://wiki.debian.org/UnattendedUpgrades

unattended_config_file="/etc/apt/apt.conf.d/50unattended-upgrades"
auto_upgrades_file="/etc/apt/apt.conf.d/20auto-upgrades"
listchanges_config_file="/etc/apt/listchanges.conf"

listchanges_config="[apt]\n\
frontend=pager\n\
which=news\n\
confirm=false\n\
save_seen=/var/lib/apt/listchanges.db"

# Modifies a config file
modify_config_file() {
    local config_file="$1"
    local config_setting_key="$2"
    local config_setting_value="$3"
    # Remove any appearances of the key from the file
    sed -i "/^$config_setting_key .*/d" "$config_file"
    # Add the updated setting
    echo "$config_setting_key \"$config_setting_value\";" >>"$config_file"
    echo "[INFO] Modified setting $config_setting_key in $config_file"
}

# Check if unattended-upgrades is installed
dpkg -s unattended-upgrades
if [ $? -ne 0 ]; then
    # Install unattended-upgrades
    echo "[INFO] Installing unattended-upgrades..."
    apt-get update
    apt-get install -y unattended-upgrades
fi

# Check and configure unattended-upgrades config file
if [ ! -f "$unattended_config_file" ]; then
    echo "[ERROR] $unattended_config_file should have been created by the unattended-upgrades package"
    exit 1
fi

echo "[INFO] Unattended-upgrades config file ($unattended_config_file) exists"

# Enable automatic removal of unused dependencies and disable automatic reboot
modify_config_file "$unattended_config_file" 'Unattended-Upgrade::Remove-Unused-Dependencies' 'true'
modify_config_file "$unattended_config_file" 'Unattended-Upgrade::Automatic-Reboot' 'false'

# Check and configure auto-upgrades config file
if [ ! -f "$auto_upgrades_file" ]; then
    # Create the file as shown in https://wiki.debian.org/UnattendedUpgrades
    echo "[INFO] Auto upgrades file ($auto_upgrades_file) does not exist. Creating it..."
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades

    # Check if the file was created
    if [ ! -f "$auto_upgrades_file" ]; then
        echo "[ERROR] $auto_upgrades_file could not be created"
        exit 1
    fi
fi

# Enable automatic updates and unattended-upgrades (file should exist now)
modify_config_file "$auto_upgrades_file" 'APT::Periodic::Update-Package-Lists' '1'
modify_config_file "$auto_upgrades_file" 'APT::Periodic::Unattended-Upgrade' '1'

# Check if apt-listchanges is installed (to see changelogs)
dpkg -s apt-listchanges
if [ $? -ne 0 ]; then
    # Install apt-listchanges
    echo "[INFO] Installing apt-listchanges..."
    apt-get update
    apt-get install -y apt-listchanges
fi

# Check if apt-listchanges was installed
dpkg -s apt-listchanges
if [ $? -ne 0 ]; then
    echo "[ERROR] apt-listchanges could not be installed"
    exit 1
fi

# Write the configuration content to the apt-listchanges.conf file
echo -e "$listchanges_config" | tee "$listchanges_config_file" >/dev/null
