#!/usr/bin/env bash
# Configura firewall UFW para el servidor VPN
# Uso: sudo ./scripts/setup-firewall.sh [--restrict-panel IP1,IP2]

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root "$0"
ROOT="$(project_root)"
load_env "$ROOT"

RESTRICT_PANEL=false
PANEL_IPS=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --restrict-panel)
            RESTRICT_PANEL=true
            PANEL_IPS="${2:-}"
            shift 2
            ;;
        *)
            shift
            ;;
    esac
done

command -v ufw &>/dev/null || die "UFW no instalado: apt install ufw"

WG_PORT="${WG_PORT:-51820}"
WEB_PORT="${WEB_PORT:-8443}"

banner
log "Configurando UFW..."

ufw --force reset
ufw default deny incoming
ufw default allow outgoing

ufw allow OpenSSH comment 'SSH'
ufw allow "${WG_PORT}/udp" comment 'WireGuard VPN'

if [[ "$RESTRICT_PANEL" == "true" && -n "$PANEL_IPS" ]]; then
    IFS=',' read -ra IPS <<< "$PANEL_IPS"
    for ip in "${IPS[@]}"; do
        ip=$(echo "$ip" | xargs)
        ufw allow from "$ip" to any port "$WEB_PORT" proto tcp comment "Panel VPN (${ip})"
        ufw allow from "$ip" to any port 443 proto tcp comment "Panel HTTPS (${ip})"
        ufw allow from "$ip" to any port 80 proto tcp comment "ACME HTTP (${ip})"
    done
    info "Panel restringido a: ${PANEL_IPS}"
else
    ufw allow "${WEB_PORT}/tcp" comment 'Panel VPN'
    ufw allow 443/tcp comment 'HTTPS Panel'
    ufw allow 80/tcp comment 'ACME HTTP'
fi

ufw --force enable
ufw status verbose

log "Firewall configurado"
