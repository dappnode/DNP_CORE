#!/bin/sh

# Upgrade from 0.2.44 to 0.2.45


DAPPNODE_DIR="/usr/src/dappnode"
HOST_SCRIPTS_DIR="$DAPPNODE_DIR/scripts"
DAPPNODE_ACCESS_CREDENTIALS="$HOST_SCRIPTS_DIR/dappnode_access_credentials.sh"
DAPPNODE_PROFILE="$DAPPNODE_DIR/DNCORE/.dappnode_profile"
LOGS_DIR="$DAPPNODE_DIR/logs"

# NEW ALIASES in .dappnode_profile
# The patron: '"'"' allows to escape single quote in sed
grep -qF 'dappnode_wifi' $DAPPNODE_PROFILE ||
    sed -i '/alias dappnode_connect/a alias dappnode_wifi='"'"'cat /usr/src/dappnode/DNCORE/docker-compose-wifi.yml | grep "SSID\\\|WPA_PASSPHRASE"'"'"'' $DAPPNODE_PROFILE

grep -qF 'dappnode_wireguard' $DAPPNODE_PROFILE ||
    sed -i '/alias dappnode_connect/a alias dappnode_wireguard='"'"'docker exec -i DAppNodeCore-api.wireguard.dnp.dappnode.eth getWireguardCredentials'"'"'' $DAPPNODE_PROFILE

# NEW SCRIPT: dappnode_access_credentials.sh
[ ! -f $DAPPNODE_ACCESS_CREDENTIALS ] || [ ! -f $DAPPNODE_PROFILE ] && \
echo ".dappnode_profile OR dappnode_access_credentials.sh do not exist" && exit 1

# Call dappnode_access_credentials.sh script on every session
grep -qF "dappnode_access_credentials" $DAPPNODE_PROFILE || echo "/bin/bash ${DAPPNODE_ACCESS_CREDENTIALS}" >>$DAPPNODE_PROFILE

# LOGS MIGRATION
ls -1 *.log &>/dev/null && \
mkdir -p $LOGS_DIR && \
mv "$DAPPNODE_DIR/*.log" $LOGS_DIR || \
echo "Logs migration already done"
