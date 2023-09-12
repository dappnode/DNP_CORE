#!/bin/sh

## Motivation:
##    We have seen that clients might lose sync if the clock is not properly synchronized
## Reference:
##    https://chrony-project.org/

# Uninstall ntp
apt-get purge -y ntp

# Install or update chrony package
apt-get update
apt-get install -y chrony

# Enable on boot and restart chronyd service
sudo systemctl enable chrony
sudo systemctl restart chrony

echo "Clock should now be synchronized with NTP servers using chrony."

# Set system clock to UTC. Maintaining the RTC in the local timezone is not fully supported and will create various problems
# with time zone changes and daylight saving adjustments. Reference: https://manpages.debian.org/unstable/systemd/timedatectl.1.en.html
timedatectl set-local-rtc 0
