#!/bin/bash
STATUS_CHECK_DELAY=1m
CONTAINER_NAME=DAppNodeCore-dappmanager.dnp.dappnode.eth
DAPPMANAGER_YML=/usr/src/dappnode/DNCORE/docker-compose-dappmanager.yml 

# Copy upgrades
mkdir -p /usr/src/dappnode/DNCORE/scripts/upgrade
cp -rf ./scripts/* /usr/src/dappnode/DNCORE/scripts/upgrade
chmod +x /usr/src/dappnode/DNCORE/scripts/upgrade/*.sh
# Copy deb packages
cp -fr ./deb /usr/src/dappnode/DNCORE/scripts/upgrade/
# Copy hashes
cp ./packages-content-hash.csv /usr/src/dappnode/DNCORE/packages-content-hash.csv

# Apply all local upgrades
for filename in ./upgrades/upgrade_*.sh; do
    echo "Applying upgrade ${filename}..."
    sh "${filename}"
done

sleep $STATUS_CHECK_DELAY

STATUS=$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME)
RUNNING_IMAGE=$(docker inspect -f '{{.Config.Image}}' $CONTAINER_NAME)
YML_IMAGE=$(cat $DAPPMANAGER_YML | awk '/image/{print $2}' | tr -d "'")
WORKAROUND_VERSION="0.2.25"

if [[ $STATUS != "true" ]]; then
    echo "Starting the dappmanager due to the DAppNodeCore-core.dnp.dappnode.eth workaround STATUS != true"
    docker-compose -f $DAPPMANAGER_YML up -d <&-
elif [[ $RUNNING_IMAGE != $YML_IMAGE ]];then
    RUNNING_VERSION=$(echo $RUNNING_IMAGE | awk -F":" '{print $2}')
    YML_VERSION=$(echo $YML_IMAGE | awk -F":" '{print $2}')
    if [ "$(printf '%s\n' "$RUNNING_VERSION" "$WORKAROUND_VERSION" | sort -V | head -n1)" != "$WORKAROUND_VERSION" ]; then
            echo "Restarting the dappmanager due to the DAppNodeCore-core.dnp.dappnode.eth workaround" 
            echo "YML_VERSION=${YML_VERSION} - RUNNING_VERSION=${RUNNING_VERSION}"
            docker-compose -f $DAPPMANAGER_YML up -d <&-
    fi
fi