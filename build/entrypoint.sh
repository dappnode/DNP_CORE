#!/bin/sh

docker-compose -f /usr/src/app/DNCORE/docker-compose-bind.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-ipfs.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-ethchain.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-ethforward.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-vpn.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-wamp.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-dappmanager.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-admin.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-wifi.yml up -d

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
