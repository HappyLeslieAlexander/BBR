#!/bin/sh
# POSIX-compliant BBR enabler for Linux (Debian/Ubuntu, Alpine, RHEL/Alma/Rocky)
# and FreeBSD.

set -eu

PATH=/sbin:/usr/sbin:/bin:/usr/bin:$PATH

log() {
    printf '%s\n' "$*"
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

need_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "missing required command: $1"
}

append_if_missing() {
    file=$1
    line=$2

    if [ ! -f "$file" ]; then
        : > "$file"
    fi

    if ! grep -Eq "^[[:space:]]*${line%%=*}[[:space:]]*=" "$file"; then
        printf '%s\n' "$line" >> "$file"
    fi
}

ensure_root() {
    if [ "$(id -u)" -eq 0 ]; then
        return 0
    fi

    if command -v sudo >/dev/null 2>&1; then
        exec sudo sh "$0" "$@"
    elif command -v doas >/dev/null 2>&1; then
        exec doas sh "$0" "$@"
    else
        die "please run as root (or via sudo/doas)"
    fi
}

persist_linux_sysctl() {
    sysctl_file=""

    if [ -d /etc/sysctl.d ]; then
        sysctl_file=/etc/sysctl.d/99-bbr.conf
    else
        sysctl_file=/etc/sysctl.conf
    fi

    append_if_missing "$sysctl_file" 'net.core.default_qdisc=fq'
    append_if_missing "$sysctl_file" 'net.ipv4.tcp_congestion_control=bbr'

    log "Persisted Linux sysctl settings in $sysctl_file"
}

enable_linux_bbr() {
    need_cmd sysctl

    # Try to load optional modules if present. Ignore failure because they may be built-in.
    if command -v modprobe >/dev/null 2>&1; then
        modprobe sch_fq >/dev/null 2>&1 || true
        modprobe tcp_bbr >/dev/null 2>&1 || true
    fi

    sysctl -w net.core.default_qdisc=fq >/dev/null
    sysctl -w net.ipv4.tcp_congestion_control=bbr >/dev/null

    persist_linux_sysctl

    cc_algo=$(sysctl -n net.ipv4.tcp_congestion_control 2>/dev/null || printf 'unknown')
    qdisc=$(sysctl -n net.core.default_qdisc 2>/dev/null || printf 'unknown')

    log "Linux BBR enabled: congestion_control=$cc_algo, default_qdisc=$qdisc"
}

append_loader_if_missing() {
    file=$1
    key=$2
    value=$3

    if [ ! -f "$file" ]; then
        : > "$file"
    fi

    if ! grep -Eq "^[[:space:]]*${key}[[:space:]]*=" "$file"; then
        printf '%s="%s"\n' "$key" "$value" >> "$file"
    fi
}

persist_freebsd() {
    need_cmd sysctl

    append_loader_if_missing /boot/loader.conf tcp_rack_load YES
    append_loader_if_missing /boot/loader.conf tcp_bbr_load YES

    append_if_missing /etc/sysctl.conf 'net.inet.tcp.functions_default=bbr'

    log "Persisted FreeBSD module/sysctl settings in /boot/loader.conf and /etc/sysctl.conf"
}

enable_freebsd_bbr() {
    need_cmd sysctl

    if command -v kldload >/dev/null 2>&1; then
        kldload tcp_rack >/dev/null 2>&1 || true
        kldload tcp_bbr >/dev/null 2>&1 || true
    fi

    sysctl net.inet.tcp.functions_default=bbr >/dev/null

    persist_freebsd

    stack=$(sysctl -n net.inet.tcp.functions_default 2>/dev/null || printf 'unknown')

    log "FreeBSD BBR enabled: functions_default=$stack"
}

main() {
    ensure_root "$@"

    os=$(uname -s)
    case "$os" in
        Linux)
            enable_linux_bbr
            ;;
        FreeBSD)
            enable_freebsd_bbr
            ;;
        *)
            die "unsupported OS: $os"
            ;;
    esac
}

main "$@"
