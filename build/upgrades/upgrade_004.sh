#!/bin/sh

# Upgrade from 0.2.26 to 0.2.27
# Fix command so it's non blocking profile at login
grep -qF 'docker run --rm -ti -v dncore_vpndnpdappnodeeth_data:/usr/src/app/secrets' /usr/src/app/DNCORE/.dappnode_profile ||
    sed -i "s,docker run --rm -v dncore_vpndnpdappnodeeth_data:/usr/src/app/secrets,docker run --rm -ti -v dncore_vpndnpdappnodeeth_data:/usr/src/app/secrets,g" /usr/src/app/DNCORE/.dappnode_profile
