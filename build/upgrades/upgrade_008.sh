#!/bin/sh

# Upgrade from 0.2.47 to 0.2.48

DAPPNODE_DIR="/usr/src/dappnode"
DAPPNODE_ACCESS_CREDENTIALS="${DAPPNODE_DIR}/scripts/dappnode_access_credentials.sh"
DAPPNODE_PROFILE="${DAPPNODE_DIR}/DNCORE/.dappnode_profile"
WELCOME_MESSAGE="echo -e '\nChoose a way to connect to your DAppNode, then go to \\\e[1mhttp://my.dappnode\\\e[0m\n\n\\\e[1m- Wifi\\\e[0m\t\tScan and connect to DAppNodeWIFI. Get wifi credentials with \\\e[32mdappnode_wifi\\\e[0m\n\n\\\e[1m- Local Proxy\\\e[0m\tConnect to the same router as your DAppNode. Then go to \\\e[1mhttp://dappnode.local\\\e[0m\n\n\\\e[1m- Wireguard\\\e[0m\tDownload Wireguard app on your device. Get your dappnode wireguard credentials with \\\e[32mdappnode_wireguard\\\e[0m\n\n\\\e[1m- Open VPN\\\e[0m\tDownload OPen VPN app on your device. Get your openVPN creds with \\\e[32mdappnode_openvpn\\\e[0m\n\n\nTo see a full list of commands available execute \\\e[32mdappnode_help\\\e[0m\n'"

# 1. Copy new profile v0.2.48 with new aliases
echo "Copying new profile..."
grep -qF "dappnode_help" $DAPPNODE_PROFILE || cp -rf /usr/src/app/hostScripts/.dappnode_profile $DAPPNODE_PROFILE

# 2. New welcome message
# Remove return from profile
echo "Removing return from profile..."
sed -i '/return/d' $DAPPNODE_PROFILE
# Add executiong of welcome_message at the end of the profile
echo "Adding welcome message at the end of profile..."
grep -qF "Choose a way to connect to your DAppNode" $DAPPNODE_PROFILE || sed -i '$a\'"${WELCOME_MESSAGE}"'' $DAPPNODE_PROFILE

# 3. Copy new dappnode_access_credentials.script v0.2.48
echo "Copying new access_credentials script"
[ -f $DAPPNODE_ACCESS_CREDENTIALS ] && grep -qF "line_separator" $DAPPNODE_ACCESS_CREDENTIALS || cp -rf /usr/src/app/hostScripts/dappnode_access_credentials.sh $DAPPNODE_ACCESS_CREDENTIALS