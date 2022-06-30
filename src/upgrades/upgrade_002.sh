#!/bin/sh

# Upgrade from 0.2.47 to 0.2.48

DAPPNODE_DIR="/usr/src/dappnode"
LOGS_DIR="/usr/src/dappnode/logs"
DAPPNODE_ACCESS_CREDENTIALS="${DAPPNODE_DIR}/scripts/dappnode_access_credentials.sh"
DAPPNODE_PROFILE="${DAPPNODE_DIR}/DNCORE/.dappnode_profile"
MOTD="/etc/motd"
WELCOME_MESSAGE="\nChoose a way to connect to your DAppNode, then go to \e[1mhttp://my.dappnode\e[0m\n\n\e[1m- Wifi\e[0m\t\tScan and connect to DAppNodeWIFI. Get wifi credentials with \e[32mdappnode_wifi\e[0m\n\n\e[1m- Local Proxy\e[0m\tConnect to the same router as your DAppNode. Then go to \e[1mhttp://dappnode.local\e[0m\n\n\e[1m- Wireguard\e[0m\tDownload Wireguard app on your device. Get your dappnode wireguard credentials with \e[32mdappnode_wireguard\e[0m\n\n\e[1m- Open VPN\e[0m\tDownload OPen VPN app on your device. Get your openVPN creds with \e[32mdappnode_openvpn\e[0m\n\n\nTo see a full list of commands available execute \e[32mdappnode_help\e[0m\n"

# 1. Copy new profile
echo "Copying new profile..."
grep -qF "dappnode_help" $DAPPNODE_PROFILE || cp -rf /usr/src/app/hostScripts/.dappnode_profile $DAPPNODE_PROFILE
# Remove return from profile
echo "Removing return from profile..."
sed -i '/return/d' $DAPPNODE_PROFILE

# 2. New welcome message
echo "Adding welcome message to ${MOTD}..."
[ -f $MOTD ] && { grep -qF "Choose a way to connect to your DAppNode" $MOTD || echo -e "$WELCOME_MESSAGE" >>$MOTD; }

# 3. Copy new dappnode_access_credentials.script
echo "Copying new access_credentials script"
[ -f $DAPPNODE_ACCESS_CREDENTIALS ] && grep -qF "line_separator" $DAPPNODE_ACCESS_CREDENTIALS || cp -rf /usr/src/app/hostScripts/dappnode_access_credentials.sh $DAPPNODE_ACCESS_CREDENTIALS

# LOGS MIGRATION: logs dir was changed to /usr/src/dappnode/logs/
ls -1 *.log &>/dev/null &&
  mkdir -p $LOGS_DIR &&
  mv "$DAPPNODE_DIR/*.log" $LOGS_DIR ||
  echo "Logs migration already done"
