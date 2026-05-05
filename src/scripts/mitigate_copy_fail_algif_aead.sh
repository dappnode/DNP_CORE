#!/bin/sh

# Host-side mitigation for CVE-2026-31431 (Copy Fail).
# The permanent fix is a patched kernel. Until then, block the vulnerable
# algif_aead userspace crypto module and unload it if it is currently loaded.

MODULE="algif_aead"
MODPROBE_DIR="/etc/modprobe.d"
MODPROBE_CONF="${MODPROBE_DIR}/dappnode-disable-algif_aead.conf"
MODPROBE_RULE="install ${MODULE} /bin/false"

# Check if the module is currently loaded
module_is_loaded() {
    grep -qE "^${MODULE}[[:space:]]" /proc/modules 2>/dev/null
}

# Check if a modprobe rule already exists to disable the module
module_has_disable_rule() {
    for conf in "${MODPROBE_DIR}"/*.conf; do
        [ -e "$conf" ] || continue
        grep -qE "^[[:space:]]*install[[:space:]]+${MODULE}[[:space:]]+/bin/false([[:space:]]|$)" "$conf" && return 0
    done
    return 1
}

# Attempt to unload the module using various common tools and paths
# Returns 0 if the module was successfully unloaded, or 1 if it could not be unloaded
unload_module() {
    if command -v rmmod >/dev/null 2>&1 && rmmod "$MODULE" 2>/dev/null; then
        return 0
    fi

    if [ -x /sbin/rmmod ] && /sbin/rmmod "$MODULE" 2>/dev/null; then
        return 0
    fi

    if [ -x /usr/sbin/rmmod ] && /usr/sbin/rmmod "$MODULE" 2>/dev/null; then
        return 0
    fi

    if command -v modprobe >/dev/null 2>&1 && modprobe -r "$MODULE" 2>/dev/null; then
        return 0
    fi

    if [ -x /sbin/modprobe ] && /sbin/modprobe -r "$MODULE" 2>/dev/null; then
        return 0
    fi

    if [ -x /usr/sbin/modprobe ] && /usr/sbin/modprobe -r "$MODULE" 2>/dev/null; then
        return 0
    fi

    return 1
}

# Main logic
echo "[INFO] Applying CVE-2026-31431 mitigation for ${MODULE}"

mkdir -p "$MODPROBE_DIR"

if module_has_disable_rule; then
    echo "[INFO] ${MODULE} already has a modprobe disable rule"
else
    if {
        echo "# DAppNode mitigation for CVE-2026-31431 (Copy Fail)"
        echo "# Blocks the vulnerable AF_ALG AEAD module until the host kernel is patched."
        echo "# Remove this file if AF_ALG AEAD support is required after applying a fixed kernel."
        echo "$MODPROBE_RULE"
    } > "$MODPROBE_CONF"; then
        echo "[INFO] Created ${MODPROBE_CONF}"
    else
        echo "[WARN] Could not create ${MODPROBE_CONF}"
    fi
fi

if module_is_loaded; then
    echo "[INFO] ${MODULE} is loaded; attempting to unload it"
    if unload_module; then
        echo "[INFO] ${MODULE} unloaded"
    else
        echo "[WARN] Could not unload ${MODULE}; reboot the host to complete the mitigation"
    fi
else
    echo "[INFO] ${MODULE} is not currently loaded"
fi

if module_is_loaded; then
    echo "[WARN] ${MODULE} is still loaded; reboot or unload it manually to complete the mitigation"
elif [ -d "/sys/module/${MODULE}" ]; then
    echo "[WARN] ${MODULE} appears to be built into this kernel; use a patched kernel or block AF_ALG with seccomp"
else
    echo "[INFO] CVE-2026-31431 mitigation active"
fi
