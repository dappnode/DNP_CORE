#!/bin/bash
set -euo pipefail

USBMOUNT_PKG="usbmount_0.0.24_all.deb"
USBMOUNT_URL="https://github.com/dappnode/usbmount/releases/download/v0.0.24/$USBMOUNT_PKG"
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

if [ "$ID" == "ubuntu" ]; then
    DEBIAN_FRONTEND=noninteractive apt update -y
    DEBIAN_FRONTEND=noninteractive apt install -y usbmount
elif [ "$ID" == "debian" ]; then
    mkdir -p "$TMP_DIR"
    wget -O "/tmp/$USBMOUNT_PKG" "$USBMOUNT_URL"
    apt install -y "/tmp/$USBMOUNT_PKG"
else
    echo "Distribution not supported, exiting."
    exit 1
fi

echo "-> usbmount package installed successfully."
