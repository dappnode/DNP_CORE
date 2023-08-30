#!/bin/sh

## Motivation:
##    We have seen that clients might lose sync if the clock is not properly synchronized
## Reference:
##    https://wiki.debian.org/NTP

# Install ntp package
apt-get update
apt-get install -y ntp

# Enable on boot and restart ntp service
sudo systemctl enable ntp
sudo systemctl restart ntp

echo "Clock should now be synchronized with NTP servers."

# Set system clock to UTC. Maintaining the RTC in the local timezone is not fully supported and will create various problems
# with time zone changes and daylight saving adjustments. Reference: https://manpages.debian.org/unstable/systemd/timedatectl.1.en.html
timedatectl set-local-rtc 0
