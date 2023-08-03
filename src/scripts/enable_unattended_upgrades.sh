#!/bin/sh

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

unattended_upgrades_config="
// Automatically upgrade packages from these (origin:archive) pairs\n\
Unattended-Upgrade::Allowed-Origins {\n\
\"${distro_id}:${distro_codename}\";\n\
\"${distro_id}:${distro_codename}-security\";\n\
\"${distro_id}ESMApps:${distro_codename}-apps-security\";\n\
\"${distro_id}ESM:${distro_codename}-infra-security\";\n\
\"Docker:${distro_codename}\";\n\
};\n\
\n\
// Do not upgrade development release automatically\n\
Unattended-Upgrade::DevRelease "false";\n\
\n\
// Automatically fix unclean dpkg exit\n\
Unattended-Upgrade::AutoFixInterruptedDpkg "true";\n\
\n\
// Reduce upgrade steps to allow interruptions\n\
Unattended-Upgrade::MinimalSteps "true";\n\
\n\
// Do not install updates when machine is shutting down\n\
Unattended-Upgrade::InstallOnShutdown "false";\n\
\n\
// Remove unused automatically installed kernel-related packages\n\
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";\n\
\n\
// Do automatic removal of newly unused dependencies after the upgrade\n\
Unattended-Upgrade::Remove-New-Unused-Dependencies "true";\n\
\n\
// Do automatic removal of unused packages after the upgrade (apt-get autoremove)\n\
Unattended-Upgrade::Remove-Unused-Dependencies "false";\n\
\n\
// Do not automatically reboot (/var/run/reboot-required found) after the upgrade\n\
Unattended-Upgrade::Automatic-Reboot "false";\n\
\n\
// Non-verbose logging\n\
Unattended-Upgrade::Verbose "false";\n\
"

auto_upgrades_config="
APT::Periodic::Update-Package-Lists \"1\";
APT::Periodic::Unattended-Upgrade \"1\";
"

# Install package if not installed
install_package() {
    local package_name="$1"
    apt-get update
    dpkg -s "$package_name" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "[INFO] Installing $package_name..."
        apt-get install -y "$package_name"
    else
        echo "[INFO] $package_name is already installed"
    fi
}

# Verifies if package is installed
verify_package_installed() {
    local package_name="$1"
    if ! dpkg-query -W "$package_name" >/dev/null 2>&1; then
        echo "[ERROR] $package_name is not installed"
        exit 1
    else
        echo "[INFO] $package_name is installed"
    fi
}

write_content_to_file() {
    local content="$1"
    local file="$2"

    if [ ! -f "$file" ]; then
        echo "[ERROR] $file does not exist"
        exit 1
    fi

    echo -e "$content" | tee "$file" >/dev/null

    if [ $? -eq 0 ]; then
        echo "[INFO] Modified $file"
    else
        echo "[INFO] $file was not modified"
    fi
}

# Create apt.conf.d directory if it does not exist
mkdir -p /etc/apt/apt.conf.d/

# Install tools if not installed
install_package sed
install_package coreutils

# Install unattended-upgrades if not installed
install_package unattended-upgrades

# Verify unattended-upgrades was installed
verify_package_installed unattended-upgrades

# Set custom config for unattended-upgrades
write_content_to_file "$unattended_upgrades_config" "$unattended_config_file"

# Check and configure auto-upgrades config file
if [ ! -f "$auto_upgrades_file" ]; then
    # Create the file as shown in https://wiki.debian.org/UnattendedUpgrades
    echo "[INFO] Auto upgrades file ($auto_upgrades_file) does not exist. Creating it..."
    echo unattended-upgrades unattended-upgrades/enable_auto_updates boolean true | debconf-set-selections
    dpkg-reconfigure -f noninteractive unattended-upgrades
fi

# Enable automatic updates and unattended-upgrades (file should exist now)
write_content_to_file "$auto_upgrades_config" "$auto_upgrades_file"

# Install apt-listchanges if not installed
install_package apt-listchanges

# Check if apt-listchanges was installed
verify_package_installed apt-listchanges

# Write the configuration content to the apt-listchanges.conf file
echo -e "$listchanges_config" | tee "$listchanges_config_file" >/dev/null
