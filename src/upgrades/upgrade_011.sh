#!/bin/sh

# Upgrade from 0.2.58 to 0.2.59

# Run script on the host with the nsenter tool
docker run --rm --privileged --pid=host -t alpine:3.8 nsenter -t 1 -m -u -n -i /usr/src/dappnode/DNCORE/scripts/upgrade/add_swap.sh
