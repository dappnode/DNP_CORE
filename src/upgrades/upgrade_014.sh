#!/bin/sh
# Apply the reversible interim mitigation on Ubuntu; never install proposed kernels.
set -eu
docker run --rm --privileged --pid=host alpine:3.18.2 \
    nsenter -t 1 -m -u -n -i /bin/bash \
    /usr/src/dappnode/DNCORE/scripts/upgrade/mitigate_cve_2026_98432.sh install
