#!/bin/sh

cp ./scripts/install_usbmount.sh /usr/src/app/DNCORE/scripts/upgrade
chmod +x /usr/src/app/DNCORE/scripts/upgrade/install_usbmount.sh

# Run script on the host with the nsenter tool
docker run --privileged --pid=host -t alpine:3.8 nsenter -t 1 -m -u -n -i /usr/src/app/DNCORE/scripts/upgrade/install_usbmount.sh
