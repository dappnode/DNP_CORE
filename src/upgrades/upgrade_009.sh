#!/bin/sh

# Bug fix for DAPPMANAGER 0.2.44

# Check if DAPPMANAGER is in bugged version
DAPPMANAGER_VERSION=$(docker inspect --format='{{index .Config.Labels "dappnode.dnp.version"}}' DAppNodeCore-dappmanager.dnp.dappnode.eth)

if [ $DAPPMANAGER_VERSION != "0.2.44" ]; then
  echo "DAPPMANAGER $DAPPMANAGER_VERSION is not in bug_version_0.2.44"
  exit 0
fi

# If in bugged version fix the line in hot editing the source file
# https://github.com/dappnode/DNP_DAPPMANAGER/commit/d949cc655d9ab2350c6d87338bd19d85033b4831#diff-4fe81a2b0f3484bb04b5aa3b2ed674d31bd529461af2086f506c507d6fabe47aR109
# From `dnpName.endsWith(".dnp.dappnode.eth")`
# To `!dnpName.endsWith(".dnp.dappnode.eth")`
# TODO

# Restart container to re-run DAPPMANAGER app with fixed code
# TODO

# Self destruct
# TODO
