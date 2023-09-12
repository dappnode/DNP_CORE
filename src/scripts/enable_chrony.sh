#!/bin/sh

## Motivation:
##    We have seen that clients might lose sync if the clock is not properly synchronized
## Reference:
##    https://chrony-project.org/

# Check if ntp is installed and remove it if it is
if dpkg -l ntp | grep "^ii"; then
    echo "Stopping, disabling, and removing ntp package..."
    sudo systemctl stop ntp
    sudo systemctl disable ntp
    sudo apt-get purge -y ntp
fi

# Check if systemd-timesyncd is active and disable it
if systemctl is-active --quiet systemd-timesyncd; then
    echo "Stopping and disabling systemd-timesyncd..."
    sudo systemctl stop systemd-timesyncd
    sudo systemctl disable systemd-timesyncd
fi

# Install or update chrony package
apt-get update
apt-get install -y chrony

# Check if chrony is already syncing properly
if ! chronyc tracking | grep -q "Leap status\s\+:\s\+Normal"; then
    # Enable on boot and restart chronyd service only if not syncing properly
    sudo systemctl enable chrony
    sudo systemctl restart chrony
    echo "Clock should now be synchronized with NTP servers using chrony."
else
    echo "Clock is already synchronized with NTP servers using chrony."
fi

# Set system clock to UTC. Maintaining the RTC in the local timezone is not fully supported and will create various problems
# with time zone changes and daylight saving adjustments. Reference: https://manpages.debian.org/unstable/systemd/timedatectl.1.en.html
timedatectl set-local-rtc 0
