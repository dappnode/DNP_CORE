#!/bin/bash
set -euo pipefail

USBMOUNT_PKG="usbmount_0.0.200_all.deb"
USBMOUNT_PATH="/usr/src/dappnode/DNCORE/scripts/upgrade/deb/$USBMOUNT_PKG"
TMP_DIR="/tmp/dappnode"

if [ ! -f "/etc/os-release" ]; then
    echo "Cannot detect OS flavor, exiting."
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root."
    exit 1
fi

source /etc/os-release

if [ "$ID" == "ubuntu" ] || [ "$ID" == "debian" ]; then
    DEBIAN_FRONTEND=noninteractive apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y "${USBMOUNT_PATH}"
else
    echo "Distribution not supported, exiting."
    exit 1
fi

echo "-> ${USBMOUNT_PKG} package installed successfully."
