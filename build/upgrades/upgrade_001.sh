#!/bin/sh

# Upgrade from 0.1.x to 0.2.0
grep -qF 'alias dappnode_get=' /usr/src/app/DNCORE/.dappnode_profile || sed  -i "/alias dappnode_start/a alias dappnode_get='docker exec -t DAppNodeCore-vpn.dnp.dappnode.eth vpncli get'" /usr/src/app/DNCORE/.dappnode_profile
grep -qF 'IPSec' /usr/src/app/DNCORE/.dappnode_profile && sed  -i "s,L2TP/IPSec,OpenVPN," /usr/src/app/DNCORE/.dappnode_profile
grep -qF 'my\.admin\.dnp\.dappnode\.eth' /usr/src/app/DNCORE/.dappnode_profile && sed  -i "s/my\.admin\.dnp\.dappnode\.eth/my\.dappnode/" /usr/src/app/DNCORE/.dappnode_profile
