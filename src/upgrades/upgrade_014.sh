#!/bin/sh

# Mitigate CVE-2026-31431 (Copy Fail)
# Run the mitigation on the host so the loaded kernel module can be removed
# immediately. The core container can write /etc through the bind mount, but it
# does not have CAP_SYS_MODULE in the host namespace.
docker run --rm --privileged --pid=host -t alpine:3.8 nsenter -t 1 -m -u -n -i /usr/src/dappnode/DNCORE/scripts/upgrade/mitigate_copy_fail_algif_aead.sh
