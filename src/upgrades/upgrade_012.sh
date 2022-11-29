#!/bin/sh

# Upgrade from 0.2.61 to 0.2.62

# Add the dappnode IPFS peer in order to have a more resilience IPFS download content in each dappnode.
# Users running IPFS in local mode will benefit from it.

DAPPNODE_IPFS_PEER="/ip4/167.86.114.131/tcp/4001/p2p/QmfB6dT5zxUq1BXiXisgcZKYkvjywdDYBK5keRaqDKH633"
IPFS_CONTAINER="DAppNodeCore-ipfs.dnp.dappnode.eth"
# Make sure the IPFS docker container is installed and running
docker ps | grep -q $IPFS_CONTAINER || { echo "Container ${IPFS_CONTAINER} not found" exit 0; }
# Make sure the IPFS docker container is running
docker inspect -f '{{.State.Running}}' $IPFS_CONTAINER | grep -q "true" || { echo "Container ${IPFS_CONTAINER} is not running" exit 0; }
# Get the IPFS container IP from the network "dncore_network"

IPFS_CONTAINER_IP=$(docker inspect -f '{{ .NetworkSettings.Networks.dncore_network.IPAddress }}' $IPFS_CONTAINER)

# Add the IPFS peer
echo "Adding IPFS peer ${IPFS_CONTAINER_IP}"
curl -X POST http://"${IPFS_CONTAINER_IP}":5001/api/v0/swarm/peering/add?arg="${DAPPNODE_IPFS_PEER}"