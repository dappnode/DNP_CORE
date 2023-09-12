#!/bin/sh

# Upgrade from 0.2.77 to 0.2.78

# Ensure system clock is synchronized with NTP servers to avoid issues with Ethereum client synchronization

# Run script on the host with the nsenter tool
docker run --rm --privileged --pid=host -t alpine:3.8 nsenter -t 1 -m -u -n -i /usr/src/dappnode/DNCORE/scripts/upgrade/enable_chrony.sh
