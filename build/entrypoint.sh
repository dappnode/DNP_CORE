#!/bin/bash
STATUS_CHECK_DELAY=1m
CONTAINER_NAME=DAppNodeCore-dappmanager.dnp.dappnode.eth
DAPPMANAGER_YML=/usr/src/app/DNCORE/docker-compose-dappmanager.yml 

# Copy host scripts and packages
mkdir -p /usr/src/app/DNCORE/scripts/upgrade
cp -rf ./scripts/* /usr/src/app/DNCORE/scripts/upgrade
chmod +x /usr/src/app/DNCORE/scripts/upgrade/*.sh
cp -fr ./deb /usr/src/app/DNCORE/scripts/upgrade/
cp ./packages-content-hash.csv /usr/src/app/DNCORE/packages-content-hash.csv

# Apply all local upgrades
for filename in ./upgrades/upgrade_*.sh; do
    echo "Applying upgrade ${filename}..."
    sh "${filename}"
done

sleep $STATUS_CHECK_DELAY

STATUS=$(docker inspect -f '{{.State.Running}}' $CONTAINER_NAME)
RUNNING_IMAGE=$(docker inspect -f '{{.Config.Image}}' $CONTAINER_NAME)
YML_IMAGE=$(cat $DAPPMANAGER_YML | awk '/image/{print $2}' | tr -d "'")

if [[ $STATUS != "true" ]]; then
    docker-compose -f $DAPPMANAGER_YML up -d <&-
else
    RUNNING_VERSION=$(echo $RUNNING_IMAGE | awk -F":" '{print $2}')
    YML_VERSION=$(echo $YML_IMAGE | awk -F":" '{print $2}')
    if [ "$(printf '%s\n' "$RUNNING_VERSION" "$YML_VERSION" | sort -V | head -n1)" != "$YML_VERSION" ]; then
            docker-compose -f $DAPPMANAGER_YML up -d <&-
    fi
fi


