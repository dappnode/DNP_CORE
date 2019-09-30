#!/bin/sh

# Upgrade from 0.2.11 to 0.2.12
docker cp DAppNodeCore-vpn.dnp.dappnode.eth:/usr/src/app/secrets/vpndb.json /usr/src/dappnode/DNCORE/migrate.json
