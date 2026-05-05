#!/bin/sh

# Mitigate CVE-2026-31431 (Copy Fail)
# Local privilege escalation via algif_aead kernel module page-cache write.
# Fix: disable algif_aead module loading and unload if currently loaded.
# Impact: none for Docker/container workloads. AF_ALG aead is not used by
# dm-crypt, LUKS, kTLS, IPsec, SSH, OpenSSL/GnuTLS defaults, or Docker.

MODPROBE_CONF="/etc/modprobe.d/disable-algif-aead.conf"

# 1. Prevent algif_aead from loading on future boots
if [ ! -f "$MODPROBE_CONF" ]; then
    echo "CVE-2026-31431: Creating ${MODPROBE_CONF} to disable algif_aead..."
    echo "# CVE-2026-31431 mitigation - disable vulnerable algif_aead module" > "$MODPROBE_CONF"
    echo "install algif_aead /bin/false" >> "$MODPROBE_CONF"
else
    echo "CVE-2026-31431: ${MODPROBE_CONF} already exists, skipping."
fi

# 2. Unload the module immediately if loaded (requires host kernel access)
docker run --rm --privileged --pid=host -t alpine:3.18 nsenter -t 1 -m -u -n -i sh -c '
    if lsmod | grep -q "^algif_aead"; then
        echo "CVE-2026-31431: algif_aead is loaded, removing..."
        rmmod algif_aead && echo "CVE-2026-31431: algif_aead removed successfully." || echo "CVE-2026-31431: WARNING - could not remove algif_aead (may be in use). It will not reload after reboot."
    else
        echo "CVE-2026-31431: algif_aead is not currently loaded."
    fi
'
