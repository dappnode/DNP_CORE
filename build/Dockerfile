FROM alpine as build

RUN apk add --update --no-cache \
    docker

WORKDIR /usr/src/app



FROM alpine

ENV DOCKER_COMPOSE_VERSION 1.25.5
ENV COMPOSE_IGNORE_ORPHANS true

WORKDIR /usr/src/app

RUN apk -u add --no-cache bash docker-compose

COPY --from=build /usr/bin/docker /usr/bin/docker
COPY entrypoint.sh .
COPY upgrades ./upgrades
COPY scripts ./scripts
COPY deb ./deb
COPY grab_hashes.sh ./grab_hashes.sh

RUN ./grab_hashes.sh && cat /usr/src/app/packages-content-hash.csv

ENTRYPOINT [ "/usr/src/app/entrypoint.sh" ]
