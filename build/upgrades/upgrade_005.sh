#!/bin/sh

# Upgrade from 0.2.26 to 0.2.27
grep -qF 'DNCORE_YMLS=' /usr/src/app/DNCORE/.dappnode_profile ||
    sed -i "/^alias dappnode_status=/i DNCORE_YMLS=\$(find \$DAPPNODE_CORE_DIR -name \"*yml\" -printf \"-f %p \")" /usr/src/app/DNCORE/.dappnode_profile

grep -qF 'docker-compose $DNCORE_YMLS' /usr/src/app/DNCORE/.dappnode_profile ||
    sed -i "s,docker-compose -f \$BIND_YML_FILE -f \$IPFS_YML_FILE -f \$ETHCHAIN_YML_FILE -f \$ETHFORWARD_YML_FILE -f \$VPN_YML_FILE -f \$WAMP_YML_FILE -f \$DAPPMANAGER_YML_FILE -f \$ADMIN_YML_FILE -f \$WIFI_YML_FILE ,docker-compose \$DNCORE_YMLS ,g" /usr/src/app/DNCORE/.dappnode_profile
