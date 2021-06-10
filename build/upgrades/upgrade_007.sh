#!/bin/sh

# Upgrade from 0.2.44 to 0.2.45

GITHUB_URL="https://github.com/dappnode/DAppNode/releases/download/v0.2.44/"
DAPPNODE_DIR="/usr/src/dappnode"
DAPPNODE_DNCORE_DIR="$DAPPNODE_DIR/DNCORE"
HOST_SCRIPTS_DIR="$DAPPNODE_DIR/scripts"
DAPPNODE_ACCESS_CREDENTIALS="$HOST_SCRIPTS_DIR/dappnode_access_credentials.sh"
DAPPNODE_PROFILE="$DAPPNODE_DNCORE_DIR/.dappnode_profile"
LOGS_DIR="$DAPPNODE_DIR/logs"

# NEW ALIASES in .dappnode_profile
# 1. Modify existng profile. New profiles contains alias dappnode_wifi, old ones not
mkdir -p $DAPPNODE_DNCORE_DIR
grep -qF "dappnode_wifi" $DAPPNODE_PROFILE || cp -rf /usr/src/app/hostScripts/.dappnode_profile $DAPPNODE_PROFILE

# NEW SCRIPT: dappnode_access_credentials.sh
mkdir -p $HOST_SCRIPTS_DIR
[ -f $DAPPNODE_ACCESS_CREDENTIALS ] || cp -rf /usr/src/app/hostScripts/.dappnode_access_credentials.sh $DAPPNODE_ACCESS_CREDENTIALS
# Call dappnode_access_credentials.sh script on every session
grep -qF "dappnode_access_credentials" $DAPPNODE_PROFILE || echo "/bin/bash ${DAPPNODE_ACCESS_CREDENTIALS}" >>$DAPPNODE_PROFILE

# LOGS MIGRATION: logs dir was changed to /usr/src/dappnode/logs/
ls -1 *.log &>/dev/null && \
mkdir -p $LOGS_DIR && \
mv "$DAPPNODE_DIR/*.log" $LOGS_DIR || \
echo "Logs migration already done"
