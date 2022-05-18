#!/bin/sh

# Upgrade from 0.2.36 to 0.2.37
grep -qF 'dappnode_connect=' /usr/src/dappnode/DNCORE/.dappnode_profile &&
    sed -i "/^alias dappnode_connect/c\alias dappnode_connect=\'docker exec -ti DAppNodeCore-vpn.dnp.dappnode.eth getAdminCredentials\'" /usr/src/dappnode/DNCORE/.dappnode_profile
