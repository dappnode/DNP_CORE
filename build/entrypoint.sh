#!/bin/sh

test -f /usr/src/app/DNCORE/bind.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/bind.dnp.dappnode.eth.env
test -f /usr/src/app/DNCORE/ipfs.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/ipfs.dnp.dappnode.eth.env
test -f /usr/src/app/DNCORE/ethchain.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/ethchain.dnp.dappnode.eth.env 
test -f /usr/src/app/DNCORE/ethforward.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/ethforward.dnp.dappnode.eth.env 
test -f /usr/src/app/DNCORE/vpn.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/vpn.dnp.dappnode.eth.env 
test -f /usr/src/app/DNCORE/wamp.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/wamp.dnp.dappnode.eth.env 
test -f /usr/src/app/DNCORE/dappmanager.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/dappmanager.dnp.dappnode.eth.env
test -f /usr/src/app/DNCORE/admin.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/admin.dnp.dappnode.eth.env
test -f /usr/src/app/DNCORE/wifi.dnp.dappnode.eth.env || touch /usr/src/app/DNCORE/wifi.dnp.dappnode.eth.envs

docker-compose -f /usr/src/app/DNCORE/docker-compose-bind.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-ipfs.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-ethchain.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-ethforward.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-vpn.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-wamp.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-dappmanager.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-admin.yml up -d
docker-compose -f /usr/src/app/DNCORE/docker-compose-wifi.yml up -d

if [ -n "`grep \"restart: always\" /usr/src/app/DNCORE/docker-compose-core.yml`" ]; then
    sed -i 's/restart: always//g' /usr/src/app/DNCORE/docker-compose-core.yml 
    docker-compose -f /usr/src/app/DNCORE/docker-compose-core.yml up -d
fi

# Upgrade from 0.1.x to 0.2.0, to be removed.
grep -qF 'alias dappnode_get=' /usr/src/app/DNCORE/.dappnode_profile || sed  -i "/alias dappnode_start/a alias dappnode_get='docker exec -t DAppNodeCore-vpn.dnp.dappnode.eth vpncli get'"