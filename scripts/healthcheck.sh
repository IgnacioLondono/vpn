#!/usr/bin/env bash
# Healthcheck del stack VPN — apto para cron y monitorización
# Uso: ./scripts/healthcheck.sh [--json]
# Exit codes: 0=healthy, 1=degraded, 2=unhealthy

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ROOT="$(project_root)"
JSON=false
[[ "${1:-}" == "--json" ]] && JSON=true

load_env "$ROOT" 2>/dev/null || true

declare -A CHECKS
OVERALL=0

check_container() {
    local name="$1"
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx "$name"; then
        local status
        status=$(docker inspect --format='{{.State.Health.Status}}' "$name" 2>/dev/null || echo "running")
        CHECKS["container_${name}"]="$status"
        [[ "$status" == "unhealthy" ]] && OVERALL=2
    else
        CHECKS["container_${name}"]="missing"
        OVERALL=2
    fi
}

check_port() {
    local port="$1" proto="$2"
    if ss -ln"${proto:0:1}" 2>/dev/null | grep -q ":${port} "; then
        CHECKS["port_${port}_${proto}"]="open"
    else
        CHECKS["port_${port}_${proto}"]="closed"
        [[ $OVERALL -lt 1 ]] && OVERALL=1
    fi
}

check_container "vpn-portal"
check_container "vpn-caddy"
check_port "${WG_PORT:-51820}" "udp"
check_port "${WEB_PORT:-51822}" "tcp"

if [[ -r /proc/sys/net/ipv4/ip_forward ]]; then
    [[ "$(cat /proc/sys/net/ipv4/ip_forward)" == "1" ]] \
        && CHECKS["ip_forward"]="enabled" \
        || { CHECKS["ip_forward"]="disabled"; OVERALL=2; }
fi

if [[ "$JSON" == "true" ]]; then
    echo -n '{"status":"'
    case $OVERALL in 0) echo -n "healthy";; 1) echo -n "degraded";; 2) echo -n "unhealthy";; esac
    echo -n '","checks":{'
    first=true
    for k in "${!CHECKS[@]}"; do
        [[ "$first" == "true" ]] && first=false || echo -n ","
        echo -n "\"${k}\":\"${CHECKS[$k]}\""
    done
    echo '}}'
else
    banner
    for k in "${!CHECKS[@]}"; do
        v="${CHECKS[$k]}"
        case "$v" in
            healthy|running|open|enabled) log "${k}: ${v}" ;;
            *) warn "${k}: ${v}" ;;
        esac
    done
    case $OVERALL in
        0) log "Estado general: HEALTHY" ;;
        1) warn "Estado general: DEGRADED" ;;
        2) error "Estado general: UNHEALTHY" ;;
    esac
fi

exit $OVERALL
