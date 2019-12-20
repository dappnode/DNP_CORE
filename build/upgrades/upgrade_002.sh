#!/bin/sh

# Upgrade from 0.2.15 to 0.2.16
grep -qF 'exec DAppNodeCore-vpn\.dnp\.dappnode\.eth getAdminCredentials' /usr/src/app/DNCORE/.dappnode_profile || \
sed  -i "s,docker exec DAppNodeCore-vpn.dnp.dappnode.eth getAdminCredentials,docker run --rm -v dncore_vpndnpdappnodeeth_data:/usr/src/app/secrets \$\(docker inspect DAppNodeCore-vpn.dnp.dappnode.eth --format '{{.Config.Image}}'\) getAdminCredentials," /usr/src/app/DNCORE/.dappnode_profile
