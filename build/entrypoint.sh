#!/bin/sh

docker-compose -f /opt/app/DNCORE/docker-compose-bind.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-ipfs.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-ethchain.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-ethforward.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-vpn.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-wamp.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-dappmanager.yml up -d
docker-compose -f /opt/app/DNCORE/docker-compose-admin.yml up -d

if [ -n "`grep \"restart: always\" /opt/app/DNCORE/docker-compose-core.yml`" ]; then
    sed -i 's/restart: always//g' /opt/app/DNCORE/docker-compose-core.yml 
    docker-compose -f /opt/app/DNCORE/docker-compose-core.yml up -d
fi