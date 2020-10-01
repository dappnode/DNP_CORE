FROM alpine as build

RUN apk add --update --no-cache \
    docker

WORKDIR /usr/src/app

FROM alpine

ENV DOCKER_COMPOSE_VERSION 1.25.5

WORKDIR /usr/src/app

COPY --from=build /usr/bin/docker /usr/bin/docker

RUN apk -u add --no-cache bash curl
    ALPINE_GLIBC_PACKAGE_VERSION="2.28-r0" && \
    ALPINE_GLIBC_BASE_PACKAGE_FILENAME="glibc-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_BIN_PACKAGE_FILENAME="glibc-bin-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    ALPINE_GLIBC_I18N_PACKAGE_FILENAME="glibc-i18n-$ALPINE_GLIBC_PACKAGE_VERSION.apk" && \
    apk add --no-cache --virtual=.build-dependencies wget ca-certificates && \
    wget \
    "https://alpine-pkgs.sgerrand.com/sgerrand.rsa.pub" \
    -O "/etc/apk/keys/sgerrand.rsa.pub" && \
    wget \
    "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BASE_URL/$ALPINE_GLIBC_PACKAGE_VERSION/$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    apk add --no-cache \
    "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME" && \
    \
    rm "/etc/apk/keys/sgerrand.rsa.pub" && \
    /usr/glibc-compat/bin/localedef --force --inputfile POSIX --charmap UTF-8 "$LANG" || true && \
    echo "export LANG=$LANG" > /etc/profile.d/locale.sh && \
    \
    apk del glibc-i18n && \
    \
    rm "/root/.wget-hsts" && \
    apk del .build-dependencies && \
    rm \
    "$ALPINE_GLIBC_BASE_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_BIN_PACKAGE_FILENAME" \
    "$ALPINE_GLIBC_I18N_PACKAGE_FILENAME"

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
