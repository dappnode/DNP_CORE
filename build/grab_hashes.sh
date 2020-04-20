#!/bin/bash
SWGET="wget -q -O-"
DAPPNODE_DIR="/usr/src/app"
CONTENT_HASH_PKGS=(geth openethereum nethermind)
CONTENT_HASH_FILE="${DAPPNODE_DIR}/packages-content-hash.csv"

grabContentHashes() {
    if [ ! -f "${CONTENT_HASH_FILE}" ]; then
        for comp in "${CONTENT_HASH_PKGS[@]}"; do
            CONTENT_HASH=$(eval ${SWGET} https://github.com/dappnode/DAppNodePackage-${comp}/releases/latest/download/content-hash)
            if [ -z $CONTENT_HASH ]; then
                echo "ERROR! Failed to find content hash of ${comp}." 2>&1 | tee -a $LOGFILE
                exit 1
            fi
            echo "${comp}.dnp.dappnode.eth,${CONTENT_HASH}" >>${CONTENT_HASH_FILE}
        done
    fi
}

echo -e "\e[32mGrabbing latest content hashes...\e[0m"
grabContentHashes
