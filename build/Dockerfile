FROM alpine as build

RUN apk add --update --no-cache \
    docker

WORKDIR /usr/src/app

FROM alpine

ENV DOCKER_COMPOSE_VERSION 1.25.5

WORKDIR /usr/src/app

COPY --from=build /usr/bin/docker /usr/bin/docker

RUN apk -u add --no-cache bash curl

RUN curl -L https://github.com/dappnode/compose/releases/download/$DOCKER_COMPOSE_VERSION/docker-compose-Linux-$(uname -m) > /usr/local/bin/docker-compose \
    && chmod +x /usr/local/bin/docker-compose

ENV COMPOSE_IGNORE_ORPHANS true

COPY entrypoint.sh .
COPY upgrades ./upgrades
COPY scripts ./scripts
COPY deb ./deb
COPY grab_hashes.sh ./grab_hashes.sh

RUN ./grab_hashes.sh && cat /usr/src/app/packages-content-hash.csv

ENTRYPOINT [ "/usr/src/app/entrypoint.sh" ]
