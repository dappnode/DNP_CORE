#!/bin/sh

# Upgrade from 0.2.76 to 0.2.77

# Switch docker installtion method to use apt official repository

# Run script on the host with the nsenter tool
docker run --rm --privileged --pid=host -t alpine:3.8 nsenter -t 1 -m -u -n -i /usr/src/dappnode/DNCORE/scripts/upgrade/docker_migration_apt.sh