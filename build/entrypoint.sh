#!/bin/bash

# Copy host scripts and packages
mkdir -p /usr/src/app/DNCORE/scripts/upgrade
cp -rf ./scripts/* /usr/src/app/DNCORE/scripts/upgrade
chmod +x /usr/src/app/DNCORE/scripts/upgrade/*.sh
cp -fr ./deb /usr/src/app/DNCORE/scripts/upgrade/

# Apply all local upgrades
for filename in ./upgrades/upgrade_*.sh; do
    echo "Applying upgrade ${filename}..."
    sh "${filename}"
done

sleep 1m
