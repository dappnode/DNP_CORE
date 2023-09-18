#!/bin/sh

## Motivation:
##    We have seen that clients might lose sync if the clock is not properly synchronized
## Reference:
##    https://chrony-project.org/

# Check if ntp is installed and remove it if so
if dpkg -l ntp | grep "^ii"; then
    echo "Stopping, disabling, and removing ntp package..."
    systemctl stop ntp
    systemctl disable ntp
    apt-get purge -y ntp
fi

# Install or update chrony package
apt-get update
if apt-get install -y chrony; then
    echo "Chrony installed successfully."

    # Check if systemd-timesyncd is active and disable it (should have been done by the chrony package install)
    echo "Stopping and disabling systemd-timesyncd..."
    systemctl stop systemd-timesyncd
    systemctl disable systemd-timesyncd

    # Check if chrony is already syncing properly
    if ! chronyc tracking | grep -q "Leap status\s\+:\s\+Normal"; then
        # Enable on boot and restart chronyd service only if not syncing properly
        systemctl enable chrony
        systemctl restart chrony
        echo "Clock should now be synchronized with NTP servers using chrony."
    else
        echo "Clock is already synchronized with NTP servers using chrony."
    fi
else
    echo "Failed to install chrony. Leaving systemd-timesyncd as-is."
fi

# Set system clock to UTC. Maintaining the RTC in the local timezone is not fully supported and will create various problems
# with time zone changes and daylight saving adjustments. Reference: https://manpages.debian.org/unstable/systemd/timedatectl.1.en.html
echo "Setting system clock to UTC..."
timedatectl set-local-rtc 0
