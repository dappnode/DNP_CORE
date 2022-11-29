FROM alpine

WORKDIR /usr/src/app

RUN apk -u add --no-cache bash docker-compose docker curl

COPY entrypoint.sh .
COPY upgrades ./upgrades
COPY scripts ./scripts
COPY deb ./deb
COPY grab_hashes.sh ./grab_hashes.sh

RUN ./grab_hashes.sh && cat /usr/src/app/packages-content-hash.csv && \
    mkdir -p /usr/src/app/hostScripts && \
    wget -qO /usr/src/app/hostScripts/dappnode_access_credentials.sh https://github.com/dappnode/DAppNode/releases/latest/download/dappnode_access_credentials.sh && \
    wget -qO /usr/src/app/hostScripts/.dappnode_profile https://github.com/dappnode/DAppNode/releases/latest/download/dappnode_profile.sh

ENV COMPOSE_IGNORE_ORPHANS true

ENTRYPOINT [ "/usr/src/app/entrypoint.sh" ]
