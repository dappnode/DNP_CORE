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
    # No prompts, no needrestart service restarts, and a bounded wait for the dpkg lock
    DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt -o DPkg::Lock::Timeout=300 update -y
    DEBIAN_FRONTEND=noninteractive NEEDRESTART_SUSPEND=1 apt -o DPkg::Lock::Timeout=300 install -y "${USBMOUNT_PATH}"
else
    echo "Distribution not supported, exiting."
    exit 1
fi

echo "-> ${USBMOUNT_PKG} package installed successfully."
