#!/bin/bash
# Interim risk reduction, NOT a kernel fix. No APT sources or packages are changed.
# https://ubuntu.com/security/CVE-2026-98432
# https://www.akamai.com/blog/security-research/cve-2026-98432-remote-uaf-linux-kernels-tcp-stack
set -Eeuo pipefail

state_dir=/var/lib/dappnode/cve-2026-98432
script_path=/usr/local/lib/dappnode/mitigate_cve_2026_98432.sh
sysctl_file=/etc/sysctl.d/99-dappnode-cve-2026-98432.conf
unit=dappnode-cve-2026-98432
unit_dir=/etc/systemd/system
status_file=/usr/src/dappnode/DNCORE/security/cve-2026-98432.status
keys=(net.mptcp.enabled net.ipv4.tcp_migrate_req)
rule=(-p tcp -m u32 --u32 '0>>24&0x0f=6:15' -m comment --comment dappnode-cve-2026-98432 -j DROP)

write_status() {
    mkdir -p "$(dirname "$status_file")"
    printf '%s\n' "$1" > "$status_file.tmp"
    mv "$status_file.tmp" "$status_file"
}

check_rules() {
    local chain key value
    for chain in PREROUTING OUTPUT; do
        iptables -w 5 -t raw -C "$chain" "${rule[@]}" >/dev/null 2>&1 || return 1
    done
    for key in "${keys[@]}"; do
        if value=$(sysctl -n "$key" 2>/dev/null); then
            [[ "$value" == 0 ]] || return 1
        elif [[ -f "$state_dir/$key.original" ]]; then
            # A previously present key becoming unreadable is not success.
            return 1
        fi
    done
}

status() {
    if [[ -f "$state_dir/removed" ]]; then
        if [[ -f "$status_file" && $(cat "$status_file") == removed ]]; then echo removed; else echo failed; fi
    elif [[ -f "$status_file" && $(cat "$status_file") == failed ]]; then
        echo failed
    elif [[ -d "$state_dir" ]] && check_rules; then
        echo mitigated
    elif [[ -f "$status_file" ]] && [[ $(cat "$status_file") == not-applicable ]]; then
        echo not-applicable
    else
        echo failed
    fi
}

apply() {
    [[ ! -f "$state_dir/removed" ]] || return 0
    local key value chain
    # Record original values once. Repeated applications never replace them.
    for key in "${keys[@]}"; do
        if value=$(sysctl -n "$key" 2>/dev/null); then
            [[ "$value" == 0 || "$value" == 1 ]]
            if [[ ! -f "$state_dir/$key.original" ]]; then
                printf '%s\n' "$value" > "$state_dir/$key.original"
            fi
        fi
    done
    # PREROUTING covers host INPUT and normal Docker bridge/DNAT forwarding.
    # OUTPUT also covers host-originated traffic and loopback. Never flush rules.
    for chain in PREROUTING OUTPUT; do
        if ! iptables -w 5 -t raw -C "$chain" "${rule[@]}" >/dev/null 2>&1; then
            iptables -w 5 -t raw -I "$chain" 1 "${rule[@]}"
        fi
    done
    for key in "${keys[@]}"; do
        if [[ -f "$state_dir/$key.original" ]]; then sysctl -w "$key=0"; fi
    done
    check_rules
    write_status mitigated
}

install() {
    # Respect an explicit administrator rollback, including future core restarts.
    [[ ! -f "$state_dir/removed" ]] || { echo 'Mitigation was explicitly removed; skipping'; return 0; }
    # shellcheck disable=SC1091
    . /etc/os-release
    if [[ ${ID:-} != ubuntu ]]; then write_status not-applicable; return 0; fi
    command -v iptables >/dev/null
    command -v sysctl >/dev/null
    # Remove the periodic checker if an earlier draft was installed on a canary.
    if [[ -f "$unit_dir/$unit.timer" ]]; then
        systemctl disable --now "$unit.timer"
        rm -f "$unit_dir/$unit.timer"
    fi
    # Make rollback available before applying any network changes.
    mkdir -p "$(dirname "$script_path")"
    if [[ $(readlink -f "$0") != "$script_path" ]]; then command install -m 755 "$0" "$script_path"; fi
    apply
    {
        echo '# Managed by Dappnode: CVE-2026-98432 temporary mitigation'
        for key in "${keys[@]}"; do
            if [[ -f "$state_dir/$key.original" ]]; then printf '%s = 0\n' "$key"; fi
        done
    } > "$sysctl_file"
    cat > "$unit_dir/$unit.service" <<UNIT
[Unit]
Description=Dappnode CVE-2026-98432 temporary risk reduction (not a kernel fix)
DefaultDependencies=no
Wants=network-pre.target
After=local-fs.target systemd-sysctl.service netfilter-persistent.service nftables.service ufw.service firewalld.service
Before=network-pre.target docker.service shutdown.target
Conflicts=shutdown.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/bash $script_path apply

[Install]
WantedBy=multi-user.target
UNIT
    systemctl daemon-reload
    systemctl enable "$unit.service"
    echo 'Temporary mitigation installed. The host still needs an official kernel fix.'
}

remove() {
    local key value chain
    # Keep this sentinel even after successful removal so core does not reapply.
    touch "$state_dir/removed"
    if [[ -f "$unit_dir/$unit.timer" ]]; then systemctl disable --now "$unit.timer"; fi
    if [[ -f "$unit_dir/$unit.service" ]]; then systemctl disable --now "$unit.service"; fi
    for chain in PREROUTING OUTPUT; do
        # Check table access separately: a missing rule is OK, permission errors aren't.
        iptables -w 5 -t raw -S "$chain" >/dev/null
        while iptables -w 5 -t raw -C "$chain" "${rule[@]}" >/dev/null 2>&1; do
            iptables -w 5 -t raw -D "$chain" "${rule[@]}"
        done
    done
    for key in "${keys[@]}"; do
        if [[ -f "$state_dir/$key.original" ]]; then
            value=$(cat "$state_dir/$key.original")
            [[ "$value" == 0 || "$value" == 1 ]]
            # Preserve later administrator changes away from the forced value.
            if [[ $(sysctl -n "$key") == 0 ]]; then sysctl -w "$key=$value"; fi
        fi
    done
    rm -f "$sysctl_file" "$unit_dir/$unit.service" "$unit_dir/$unit.timer"
    systemctl daemon-reload
    write_status removed
    echo 'Temporary mitigation removed. This does not verify kernel patch status.'
}

command=${1:-install}
case "$command" in
    install|apply|remove|status) ;;
    *) echo "Usage: $0 {install|apply|status|remove}" >&2; exit 2 ;;
esac
[[ $EUID == 0 ]] || { echo 'Must run on the host as root' >&2; exit 1; }
if [[ "$command" == status ]]; then status; exit 0; fi
mkdir -p "$state_dir"
chmod 700 "$state_dir"
exec 9>"$state_dir/lock"
flock -w 30 9
trap 'write_status failed' ERR
"$command"
