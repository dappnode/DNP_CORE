#!/bin/bash

# Operator-run Debian major release migration helper for DAppNode hosts.
# Initial supported path: Debian 11 (bullseye) -> Debian 12 (bookworm).

set -uo pipefail

TARGET_CODENAME="bookworm"
SOURCE_CODENAME="bullseye"
SOURCE_VERSION_ID="11"
SUPPORTED_TARGET="bookworm"
BASE_DIR="/root/dappnode-debian-upgrade"
MIN_VAR_MB=2048
WARN_VAR_MB=4096
MIN_BOOT_FREE_MB=300
WARN_BOOT_SIZE_MB=768

MODE=""
YES_I_UNDERSTAND="false"
RUN_DIR=""
LOG_FILE=""
TRANSCRIPT_STARTED="false"
ERROR_COUNT=0
WARN_COUNT=0
OS_ID=""
OS_VERSION_ID=""
OS_VERSION_CODENAME=""
ARCH=""
TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BOOKWORM_COMPONENTS=()

usage() {
    cat <<EOF
Usage:
  $0 --target bookworm --check
  $0 --target bookworm --prepare --yes-i-understand
  $0 --target bookworm --upgrade --yes-i-understand

Modes:
  --check      Read-only preflight report for Debian 11 -> Debian 12.
  --prepare    Bring bullseye current, back up APT state, and switch Debian APT sources to bookworm.
  --upgrade    Run the supervised bookworm upgrade after --prepare has completed.

Options:
  --target bookworm       Required. bookworm is the only supported target.
  --yes-i-understand      Required for --prepare and --upgrade.
  -h, --help              Show this help.

This script does not support skip-upgrades. Debian 11 -> Debian 13 must go
through Debian 12 first, then a separate Debian 12 -> Debian 13 migration.
EOF
}

log() {
    printf '[INFO] %s\n' "$*"
}

warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    printf '[WARN] %s\n' "$*"
}

error() {
    ERROR_COUNT=$((ERROR_COUNT + 1))
    printf '[ERROR] %s\n' "$*"
}

die() {
    printf '[ERROR] %s\n' "$*" >&2
    exit 1
}

parse_args() {
    if [ "$#" -eq 0 ]; then
        usage
        exit 2
    fi

    while [ "$#" -gt 0 ]; do
        case "$1" in
            --check|--prepare|--upgrade)
                if [ -n "$MODE" ]; then
                    die "Only one mode can be selected"
                fi
                MODE="${1#--}"
                ;;
            --target)
                shift
                if [ "$#" -eq 0 ]; then
                    die "--target requires a value"
                fi
                TARGET_CODENAME="$1"
                ;;
            --target=*)
                TARGET_CODENAME="${1#--target=}"
                ;;
            --yes-i-understand)
                YES_I_UNDERSTAND="true"
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            *)
                usage
                die "Unknown argument: $1"
                ;;
        esac
        shift
    done

    if [ -z "$MODE" ]; then
        usage
        exit 2
    fi

    if [ "$TARGET_CODENAME" != "$SUPPORTED_TARGET" ]; then
        die "Unsupported target '$TARGET_CODENAME'. Only '$SUPPORTED_TARGET' is supported."
    fi
}

require_yes_for_mutation() {
    if [ "$YES_I_UNDERSTAND" != "true" ]; then
        die "--$MODE requires --yes-i-understand"
    fi
}

load_os_release() {
    OS_ID=""
    OS_VERSION_ID=""
    OS_VERSION_CODENAME=""

    if [ -r /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        OS_ID="${ID:-}"
        OS_VERSION_ID="${VERSION_ID:-}"
        OS_VERSION_CODENAME="${VERSION_CODENAME:-}"
    fi
}

get_architecture() {
    if command -v dpkg >/dev/null 2>&1; then
        ARCH="$(dpkg --print-architecture 2>/dev/null || true)"
    else
        ARCH=""
    fi
}

create_run_dir() {
    RUN_DIR="${BASE_DIR}/${TARGET_CODENAME}/${TIMESTAMP}"
    mkdir -p "$RUN_DIR"
    LOG_FILE="${RUN_DIR}/${MODE}.log"
}

start_transcript() {
    if [ "$TRANSCRIPT_STARTED" = "true" ]; then
        return 0
    fi

    touch "$LOG_FILE"
    exec > >(tee -a "$LOG_FILE") 2>&1
    TRANSCRIPT_STARTED="true"
    log "Writing transcript to $LOG_FILE"
}

require_root() {
    if [ "$(id -u)" -ne 0 ]; then
        error "Run this script as root on the host"
    fi
}

check_current_debian_release() {
    load_os_release

    log "Detected OS: ID=${OS_ID:-unknown}, VERSION_ID=${OS_VERSION_ID:-unknown}, VERSION_CODENAME=${OS_VERSION_CODENAME:-unknown}"

    if [ "$OS_ID" != "debian" ]; then
        error "Only Debian hosts are supported"
        return
    fi

    if [ "$OS_VERSION_ID" != "$SOURCE_VERSION_ID" ] && [ "$OS_VERSION_CODENAME" != "$SOURCE_CODENAME" ]; then
        error "Expected Debian ${SOURCE_VERSION_ID} (${SOURCE_CODENAME}); found VERSION_ID=${OS_VERSION_ID:-unknown}, VERSION_CODENAME=${OS_VERSION_CODENAME:-unknown}"
    fi
}

check_architecture() {
    get_architecture
    log "Detected architecture: ${ARCH:-unknown}"

    case "$ARCH" in
        amd64|arm64)
            ;;
        *)
            error "Unsupported architecture '${ARCH:-unknown}'. Only amd64 and arm64 are supported."
            ;;
    esac
}

mount_options_for_path() {
    local path="$1"

    if command -v findmnt >/dev/null 2>&1; then
        findmnt -n -o OPTIONS --target "$path" 2>/dev/null || true
    fi
}

check_mount_rw() {
    local path="$1"
    local options

    options="$(mount_options_for_path "$path")"
    if [ -z "$options" ]; then
        warn "Could not determine mount options for $path"
        return
    fi

    case ",$options," in
        *,rw,*)
            log "$path is mounted read-write"
            ;;
        *)
            error "$path is not mounted read-write"
            ;;
    esac
}

check_dpkg_audit() {
    local audit_output

    audit_output="$(dpkg --audit 2>&1 || true)"
    if [ -n "$audit_output" ]; then
        error "dpkg reports broken or partially configured packages"
        printf '%s\n' "$audit_output"
    else
        log "dpkg audit is clean"
    fi
}

check_holds() {
    local holds

    holds="$(apt-mark showhold 2>/dev/null || true)"
    if [ -n "$holds" ]; then
        error "APT package holds must be reviewed and removed before the release upgrade"
        printf '%s\n' "$holds"
    else
        log "No APT package holds found"
    fi
}

df_avail_mb() {
    local path="$1"
    df -Pm "$path" 2>/dev/null | awk 'NR == 2 {print $4}'
}

df_size_mb() {
    local path="$1"
    df -Pm "$path" 2>/dev/null | awk 'NR == 2 {print $2}'
}

mount_source_for_path() {
    local path="$1"

    if command -v findmnt >/dev/null 2>&1; then
        findmnt -n -o SOURCE --target "$path" 2>/dev/null || true
    fi
}

check_disk_space() {
    local var_free boot_free boot_size root_source boot_source

    var_free="$(df_avail_mb /var)"
    if [ -z "$var_free" ]; then
        warn "Could not determine free space for /var"
    elif [ "$var_free" -lt "$MIN_VAR_MB" ]; then
        error "/var has ${var_free}MB free; at least ${MIN_VAR_MB}MB is required before attempting the upgrade"
    elif [ "$var_free" -lt "$WARN_VAR_MB" ]; then
        warn "/var has ${var_free}MB free; ${WARN_VAR_MB}MB or more is recommended"
    else
        log "/var free space: ${var_free}MB"
    fi

    root_source="$(mount_source_for_path /)"
    boot_source="$(mount_source_for_path /boot)"

    if [ -n "$root_source" ] && [ -n "$boot_source" ] && [ "$root_source" = "$boot_source" ]; then
        log "/boot is not a separate filesystem"
        return
    fi

    boot_free="$(df_avail_mb /boot)"
    boot_size="$(df_size_mb /boot)"

    if [ -z "$boot_free" ]; then
        warn "Could not determine free space for /boot"
    elif [ "$boot_free" -lt "$MIN_BOOT_FREE_MB" ]; then
        error "/boot has ${boot_free}MB free; at least ${MIN_BOOT_FREE_MB}MB is required"
    else
        log "/boot free space: ${boot_free}MB"
    fi

    if [ -n "$boot_size" ] && [ "$boot_size" -lt "$WARN_BOOT_SIZE_MB" ]; then
        warn "/boot size is ${boot_size}MB; Debian recommends larger /boot partitions for newer kernels"
    fi
}

check_gpgv() {
    if dpkg-query -W -f='${Status}' gpgv 2>/dev/null | grep -q "install ok installed"; then
        log "gpgv is installed"
        return
    fi

    if [ "$MODE" = "upgrade" ]; then
        error "gpgv is not installed; run --prepare first or install gpgv before upgrading"
    else
        warn "gpgv is not installed; --prepare will install it"
    fi
}

kernel_meta_package() {
    case "$ARCH" in
        amd64)
            printf '%s\n' "linux-image-amd64"
            ;;
        arm64)
            printf '%s\n' "linux-image-arm64"
            ;;
        *)
            printf '%s\n' ""
            ;;
    esac
}

check_kernel_metapackage() {
    local meta_pkg

    meta_pkg="$(kernel_meta_package)"
    if [ -z "$meta_pkg" ]; then
        return
    fi

    if dpkg-query -W -f='${Status}' "$meta_pkg" 2>/dev/null | grep -q "install ok installed"; then
        log "Kernel metapackage is installed: $meta_pkg"
        return
    fi

    if apt-cache show "$meta_pkg" >/dev/null 2>&1; then
        warn "Kernel metapackage is not installed; $meta_pkg is available and will be installed before the full upgrade"
    else
        error "Kernel metapackage is not installed and $meta_pkg is not available in APT"
    fi
}

active_list_source_lines() {
    local file

    for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
        [ -r "$file" ] || continue
        awk -v file="$file" '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*deb(-src)?[[:space:]]/ { print file ":" $0 }
        ' "$file"
    done
}

active_sources_file_stanzas() {
    local file

    for file in /etc/apt/sources.list.d/*.sources; do
        [ -r "$file" ] || continue
        awk -v file="$file" '
            function reset() {
                enabled = 1
                types = ""
                uris = ""
                suites = ""
                components = ""
            }
            function flush() {
                if (types != "" && enabled) {
                    print file ": Types=" types " URIs=" uris " Suites=" suites " Components=" components
                }
                reset()
            }
            BEGIN { reset() }
            /^[[:space:]]*$/ { flush(); next }
            /^[[:space:]]*#/ { next }
            /^Enabled:[[:space:]]*no/ { enabled = 0; next }
            /^Types:/ { types = $0; sub(/^Types:[[:space:]]*/, "", types); next }
            /^URIs:/ { uris = $0; sub(/^URIs:[[:space:]]*/, "", uris); next }
            /^Suites:/ { suites = $0; sub(/^Suites:[[:space:]]*/, "", suites); next }
            /^Components:/ { components = $0; sub(/^Components:[[:space:]]*/, "", components); next }
            END { flush() }
        ' "$file"
    done
}

active_sources_containing_suite() {
    local suite="$1"

    {
        active_list_source_lines
        active_sources_file_stanzas
    } | grep -E "(^|[[:space:]=])${suite}([[:space:]-]|$)" || true
}

active_debian_sources_containing_suite() {
    local suite="$1"

    active_sources_containing_suite "$suite" | grep -E "debian\.org|debian-security|deb\.debian|security\.debian|ftp\.[^[:space:]]*debian|/debian|file:[^[:space:]]*debian" || true
}

warn_backports_and_proposed_updates() {
    local matches

    matches="$({
        active_list_source_lines
        active_sources_file_stanzas
    } | grep -E "backports|proposed-updates" || true)"

    if [ -n "$matches" ]; then
        warn "Backports or proposed-updates entries are active and should be removed before the release upgrade"
        printf '%s\n' "$matches"
    fi
}

warn_non_debian_sources() {
    local matches

    matches="$({
        active_list_source_lines
        active_sources_file_stanzas
    } | grep -Ev "debian\.org|debian-security|deb\.debian|security\.debian|ftp\.[^[:space:]]*debian" || true)"

    if [ -n "$matches" ]; then
        warn "Possible non-Debian APT sources are active; verify they support bookworm or disable them for the upgrade"
        printf '%s\n' "$matches"
    fi
}

check_current_sources() {
    local bullseye_sources

    bullseye_sources="$(active_debian_sources_containing_suite "$SOURCE_CODENAME")"
    if [ -z "$bullseye_sources" ]; then
        warn "No active ${SOURCE_CODENAME} APT sources found; verify APT is pinned to the Debian 11 codename before --prepare"
    else
        log "Active ${SOURCE_CODENAME} APT sources found"
    fi

    warn_backports_and_proposed_updates
    warn_non_debian_sources
}

check_bookworm_sources_ready() {
    local bookworm_sources bullseye_sources

    bookworm_sources="$(active_debian_sources_containing_suite "$TARGET_CODENAME")"
    bullseye_sources="$(active_sources_containing_suite "$SOURCE_CODENAME")"

    if [ -z "$bookworm_sources" ]; then
        error "No active ${TARGET_CODENAME} APT sources found. Run --prepare before --upgrade."
    else
        log "Active ${TARGET_CODENAME} APT sources found"
    fi

    if [ -n "$bullseye_sources" ]; then
        error "Active ${SOURCE_CODENAME} APT sources remain; disable them before --upgrade"
        printf '%s\n' "$bullseye_sources"
    fi

    warn_backports_and_proposed_updates
    warn_non_debian_sources
}

check_apt_pinning() {
    local pinning

    pinning="$(
        {
            [ -r /etc/apt/preferences ] && grep -HnEv '^[[:space:]]*(#|$)' /etc/apt/preferences || true
            grep -HnEv '^[[:space:]]*(#|$)' /etc/apt/preferences.d/* 2>/dev/null || true
        } || true
    )"

    if [ -n "$pinning" ]; then
        warn "APT pinning is configured; verify it allows ${TARGET_CODENAME} packages"
        printf '%s\n' "$pinning"
    else
        log "No active APT pinning found"
    fi
}

check_leftover_config_files() {
    local leftovers

    leftovers="$(find /etc \( -name '*.dpkg-*' -o -name '*.ucf-*' -o -name '*.merge-error' \) -print 2>/dev/null | head -n 50 || true)"

    if [ -n "$leftovers" ]; then
        warn "Leftover dpkg/ucf configuration files found; review them before upgrading"
        printf '%s\n' "$leftovers"
    else
        log "No leftover dpkg/ucf configuration files found under /etc"
    fi
}

installed_firmware_packages() {
    dpkg -l 'firmware-*' 2>/dev/null | awk '$1 == "ii" { print $2 }'
}

collect_debian_components_from_list_files() {
    local file

    for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list; do
        [ -r "$file" ] || continue
        awk '
            /^[[:space:]]*#/ { next }
            /^[[:space:]]*deb[[:space:]]/ || /^[[:space:]]*deb-src[[:space:]]/ {
                line = $0
                sub(/^[[:space:]]*deb(-src)?[[:space:]]+/, "", line)
                if (line ~ /^\[/) {
                    sub(/^\[[^]]*\][[:space:]]+/, "", line)
                }
                field_count = split(line, fields, /[[:space:]]+/)
                uri = fields[1]
                suite = fields[2]
                if (uri ~ /debian/ && suite ~ /^bullseye/) {
                    for (i = 3; i <= field_count; i++) {
                        if (fields[i] != "") {
                            print fields[i]
                        }
                    }
                }
            }
        ' "$file"
    done
}

collect_debian_components_from_sources_files() {
    local file

    for file in /etc/apt/sources.list.d/*.sources; do
        [ -r "$file" ] || continue
        awk '
            function reset() {
                enabled = 1
                types = ""
                uris = ""
                suites = ""
                components = ""
            }
            function flush() {
                if (enabled && types ~ /(^|[[:space:]])deb([[:space:]]|$)/ && uris ~ /debian/ && suites ~ /(^|[[:space:]])bullseye([[:space:]-]|$)/) {
                    split(components, parts, /[[:space:]]+/)
                    for (i in parts) {
                        if (parts[i] != "") {
                            print parts[i]
                        }
                    }
                }
                reset()
            }
            BEGIN { reset() }
            /^[[:space:]]*$/ { flush(); next }
            /^[[:space:]]*#/ { next }
            /^Enabled:[[:space:]]*no/ { enabled = 0; next }
            /^Types:/ { types = $0; sub(/^Types:[[:space:]]*/, "", types); next }
            /^URIs:/ { uris = $0; sub(/^URIs:[[:space:]]*/, "", uris); next }
            /^Suites:/ { suites = $0; sub(/^Suites:[[:space:]]*/, "", suites); next }
            /^Components:/ { components = $0; sub(/^Components:[[:space:]]*/, "", components); next }
            END { flush() }
        ' "$file"
    done
}

collect_existing_debian_components() {
    {
        collect_debian_components_from_list_files
        collect_debian_components_from_sources_files
    } | awk '!seen[$0]++'
}

component_is_present() {
    local wanted="$1"
    local component

    for component in "${BOOKWORM_COMPONENTS[@]}"; do
        if [ "$component" = "$wanted" ]; then
            return 0
        fi
    done

    return 1
}

add_component() {
    local component="$1"

    if [ -z "$component" ]; then
        return
    fi

    if ! component_is_present "$component"; then
        BOOKWORM_COMPONENTS+=("$component")
    fi
}

load_bookworm_components() {
    local component firmware_packages

    BOOKWORM_COMPONENTS=()

    while IFS= read -r component; do
        add_component "$component"
    done < <(collect_existing_debian_components)

    if [ "${#BOOKWORM_COMPONENTS[@]}" -eq 0 ]; then
        add_component "main"
    fi

    firmware_packages="$(installed_firmware_packages || true)"
    if [ -n "$firmware_packages" ] || component_is_present "non-free"; then
        add_component "non-free-firmware"
    fi
}

check_non_free_firmware_component() {
    local firmware_packages existing_components

    firmware_packages="$(installed_firmware_packages || true)"
    existing_components="$(collect_existing_debian_components | tr '\n' ' ')"

    if [ -n "$firmware_packages" ] && ! printf '%s\n' "$existing_components" | grep -qw "non-free-firmware"; then
        warn "Firmware packages are installed and current Debian sources do not include non-free-firmware; generated ${TARGET_CODENAME} sources will add it"
        printf '%s\n' "$firmware_packages"
    fi

    load_bookworm_components
    if component_is_present "non-free-firmware"; then
        log "${TARGET_CODENAME} sources will include non-free-firmware"
    fi
}

report_third_party_packages() {
    local packages

    packages="$(apt list '?narrow(?installed, ?not(?origin(Debian)))' 2>/dev/null | sed '1d' | head -n 50 || true)"

    if [ -n "$packages" ]; then
        warn "Installed packages not reported as origin=Debian; review these before the release upgrade"
        printf '%s\n' "$packages"
    else
        log "No installed non-Debian packages reported by apt"
    fi
}

check_ssh_recovery() {
    if [ -n "${SSH_CONNECTION:-}" ] || [ -n "${SSH_TTY:-}" ]; then
        warn "This session appears to be over SSH. Use tmux/screen and make sure out-of-band recovery is available."
    else
        log "No SSH session detected from environment"
    fi
}

run_common_preflight() {
    ERROR_COUNT=0
    WARN_COUNT=0

    require_root
    check_current_debian_release
    check_architecture
    check_mount_rw /
    check_mount_rw /usr
    check_dpkg_audit
    check_holds
    check_disk_space
    check_gpgv
    check_kernel_metapackage
    check_apt_pinning
    check_leftover_config_files
    check_non_free_firmware_component
    report_third_party_packages
    check_ssh_recovery
}

run_check_preflight() {
    log "Running read-only ${SOURCE_CODENAME} -> ${TARGET_CODENAME} preflight"
    run_common_preflight
    check_current_sources
    print_preflight_summary
}

run_upgrade_preflight() {
    log "Running ${TARGET_CODENAME} upgrade preflight"
    run_common_preflight
    check_bookworm_sources_ready
    print_preflight_summary
}

print_preflight_summary() {
    log "Preflight completed with ${ERROR_COUNT} error(s) and ${WARN_COUNT} warning(s)"

    if [ "$ERROR_COUNT" -gt 0 ]; then
        return 1
    fi

    return 0
}

backup_state() {
    log "Backing up package and APT state to $RUN_DIR"

    cp -a /etc/apt "${RUN_DIR}/etc-apt"
    cp -a /etc/os-release "${RUN_DIR}/os-release" 2>/dev/null || true
    cp -a /etc/debian_version "${RUN_DIR}/debian_version" 2>/dev/null || true
    dpkg --get-selections '*' >"${RUN_DIR}/dpkg-selections.txt"
    apt-mark showhold >"${RUN_DIR}/apt-holds.txt"
    apt list --installed >"${RUN_DIR}/apt-installed.txt" 2>"${RUN_DIR}/apt-installed.stderr" || true
    df -h >"${RUN_DIR}/df-h.txt"
    findmnt >"${RUN_DIR}/findmnt.txt" 2>/dev/null || true
    {
        active_list_source_lines
        active_sources_file_stanzas
    } >"${RUN_DIR}/active-apt-sources.txt"
}

run_apt_update_with_releaseinfo_retry() {
    if apt-get update; then
        return 0
    fi

    warn "apt-get update failed; retrying with --allow-releaseinfo-change"
    apt-get update --allow-releaseinfo-change
}

install_prepare_helpers() {
    log "Installing release-upgrade helper packages"
    env DEBIAN_FRONTEND=noninteractive apt-get install -y \
        apt-listchanges \
        ca-certificates \
        debian-archive-keyring \
        gpgv
}

show_and_maybe_run_autoremove() {
    log "Showing apt-get autoremove simulation before making any removals"
    apt-get -s autoremove || true

    if [ ! -t 0 ]; then
        warn "No interactive terminal detected; skipping apt-get autoremove"
        return
    fi

    printf '\nType "autoremove" to run apt-get autoremove now, or press Enter to skip: '
    read -r answer
    if [ "$answer" = "autoremove" ]; then
        apt-get autoremove
    else
        warn "Skipped apt-get autoremove. Revisit removable packages before the full upgrade if disk space is tight."
    fi
}

disable_bullseye_source_files() {
    local file disabled_file

    log "Disabling active ${SOURCE_CODENAME} APT source files after backup"

    for file in /etc/apt/sources.list /etc/apt/sources.list.d/*.list /etc/apt/sources.list.d/*.sources; do
        [ -f "$file" ] || continue
        if grep -Eq "^[[:space:]]*deb(-src)?([[:space:]]|.*])[^#]*[[:space:]]${SOURCE_CODENAME}([[:space:]-]|$)|^[[:space:]]*Suites:[[:space:]].*(^|[[:space:]])${SOURCE_CODENAME}([[:space:]-]|$)" "$file"; then
            disabled_file="${file}.dappnode-disabled-${TIMESTAMP}"
            mv "$file" "$disabled_file"
            log "Disabled $file -> $disabled_file"
        fi
    done
}

write_bookworm_sources() {
    local dest="/etc/apt/sources.list.d/dappnode-bookworm.sources"
    local components_line

    load_bookworm_components
    components_line="${BOOKWORM_COMPONENTS[*]}"

    log "Writing ${TARGET_CODENAME} Debian sources with components: $components_line"
    mkdir -p /etc/apt/sources.list.d

    if [ -f "$dest" ]; then
        cp -a "$dest" "${RUN_DIR}/$(basename "$dest").pre-${TIMESTAMP}"
    fi

    cat >"$dest" <<EOF
Types: deb
URIs: https://deb.debian.org/debian
Suites: ${TARGET_CODENAME} ${TARGET_CODENAME}-updates
Components: ${components_line}
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb
URIs: https://security.debian.org/debian-security
Suites: ${TARGET_CODENAME}-security
Components: ${components_line}
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
EOF
}

prepare_release_upgrade() {
    require_yes_for_mutation

    run_check_preflight || die "Preflight has blocking errors; refusing to prepare the release upgrade"

    create_run_dir
    start_transcript
    backup_state

    log "Updating ${SOURCE_CODENAME} package lists"
    run_apt_update_with_releaseinfo_retry

    install_prepare_helpers

    log "Bringing ${SOURCE_CODENAME} packages current without a distribution upgrade"
    env DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y upgrade

    show_and_maybe_run_autoremove
    write_bookworm_sources
    disable_bullseye_source_files

    log "Preparation complete"
    log "Next step: run '$0 --target ${TARGET_CODENAME} --upgrade --yes-i-understand' from a tmux/screen session."
}

require_confirmation_phrase() {
    local phrase="$1"
    local prompt="$2"
    local answer

    if [ ! -t 0 ]; then
        die "Interactive terminal required before $phrase"
    fi

    printf '\n%s\nType "%s" to continue: ' "$prompt" "$phrase"
    read -r answer

    if [ "$answer" != "$phrase" ]; then
        die "Confirmation phrase did not match; aborting"
    fi
}

ensure_kernel_metapackage_installed() {
    local meta_pkg

    meta_pkg="$(kernel_meta_package)"
    if [ -z "$meta_pkg" ]; then
        die "Cannot determine kernel metapackage for architecture ${ARCH:-unknown}"
    fi

    if dpkg-query -W -f='${Status}' "$meta_pkg" 2>/dev/null | grep -q "install ok installed"; then
        log "Kernel metapackage already installed: $meta_pkg"
        return
    fi

    log "Installing kernel metapackage: $meta_pkg"
    apt-get install "$meta_pkg"
}

show_full_upgrade_estimate() {
    log "Showing full-upgrade disk/package estimate"
    if ! apt-get -s -o APT::Get::Trivial-Only=true full-upgrade; then
        warn "Trivial-only estimate could not complete; showing simulated full-upgrade instead"
        apt-get -s full-upgrade || true
    fi
}

post_upgrade_report() {
    local audit_output holds upgradable

    log "Post-upgrade dpkg audit"
    audit_output="$(dpkg --audit 2>&1 || true)"
    if [ -n "$audit_output" ]; then
        warn "dpkg audit still reports issues"
        printf '%s\n' "$audit_output"
    else
        log "dpkg audit is clean"
    fi

    holds="$(apt-mark showhold 2>/dev/null || true)"
    if [ -n "$holds" ]; then
        warn "APT package holds remain"
        printf '%s\n' "$holds"
    else
        log "No APT package holds remain"
    fi

    upgradable="$(apt list --upgradable 2>/dev/null | sed '1d' || true)"
    if [ -n "$upgradable" ]; then
        warn "Packages are still upgradable or held back"
        printf '%s\n' "$upgradable"
    else
        log "No upgradable packages reported by apt"
    fi

    if [ -f /var/run/reboot-required ]; then
        warn "Reboot required. Reboot from a recovery-safe session after reviewing this log: $LOG_FILE"
        if [ -f /var/run/reboot-required.pkgs ]; then
            log "Packages requesting reboot:"
            cat /var/run/reboot-required.pkgs
        fi
    else
        log "No /var/run/reboot-required marker found. A reboot is still recommended after a Debian release upgrade."
    fi
}

run_release_upgrade() {
    require_yes_for_mutation

    run_upgrade_preflight || die "Preflight has blocking errors; refusing to run the release upgrade"

    create_run_dir
    start_transcript
    backup_state

    log "Fetching ${TARGET_CODENAME} package lists"
    run_apt_update_with_releaseinfo_retry

    log "Running minimal system upgrade"
    apt-get upgrade --without-new-pkgs

    ensure_kernel_metapackage_installed
    show_full_upgrade_estimate

    require_confirmation_phrase "full-upgrade" "The next command is 'apt-get full-upgrade' for Debian ${SOURCE_VERSION_ID} -> Debian 12. Review the proposed removals carefully."

    if ! apt-get full-upgrade; then
        warn "apt-get full-upgrade failed. If the error was 'Could not perform immediate configuration', Debian release notes suggest retrying manually with: apt-get full-upgrade -o APT::Immediate-Configure=0"
        exit 1
    fi

    post_upgrade_report
    log "Formal upgrade step completed. Review $LOG_FILE, then reboot the host deliberately."
}

main() {
    parse_args "$@"

    case "$MODE" in
        check)
            run_check_preflight
            ;;
        prepare)
            prepare_release_upgrade
            ;;
        upgrade)
            run_release_upgrade
            ;;
        *)
            usage
            exit 2
            ;;
    esac
}

main "$@"
