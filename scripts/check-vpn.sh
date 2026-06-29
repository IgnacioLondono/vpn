#!/usr/bin/env bash
# Diagnóstico completo del servidor VPN
# Uso: ./scripts/check-vpn.sh

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ROOT="$(project_root)"
load_env "$ROOT" 2>/dev/null || true

SERVER_IP="${WG_HOST:-}"
WG_PORT="${WG_PORT:-51820}"
WEB_PORT="${WEB_PORT:-8443}"

banner
info "Diagnóstico del stack VP´N"
echo ""

# Docker
if command -v docker &>/dev/null; then
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'vpn-wireguard'; then
        log "Contenedor vpn-wireguard: running"
        docker inspect vpn-wireguard --format='  Health: {{.State.Health.Status}}' 2>/dev/null || true
    else
        warn "Contenedor vpn-wireguard: no encontrado"
    fi

    if docker ps --format '{{.Names}}' 2>/dev/null | grep -qx 'vpn-caddy'; then
        log "Contenedor vpn-caddy: running"
    fi
else
    warn "Docker no instalado"
fi

# IP forwarding
if [[ -r /proc/sys/net/ipv4/ip_forward ]]; then
    [[ "$(cat /proc/sys/net/ipv4/ip_forward)" == "1" ]] \
        && log "IP forwarding: habilitado" \
        || warn "IP forwarding: deshabilitado"
fi

# WireGuard nativo
if ip link show wg0 &>/dev/null 2>&1; then
    log "Interfaz wg0 activa"
    wg show wg0 2>/dev/null | sed 's/^/  /'
fi

# Puertos
if command -v ss &>/dev/null; then
    ss -lnu 2>/dev/null | grep -q ":${WG_PORT} " && log "Puerto UDP ${WG_PORT}: escuchando" || warn "Puerto UDP ${WG_PORT}: no detectado"
    ss -lnt 2>/dev/null | grep -q ":${WEB_PORT} " && log "Puerto TCP ${WEB_PORT}: escuchando" || info "Puerto TCP ${WEB_PORT}: no expuesto (normal con SSL)"
fi

# Panel web
if [[ -n "$SERVER_IP" ]]; then
    echo ""
    info "Comprobando panel web..."
    HTTP_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:${WEB_PORT}/" 2>/dev/null || echo "000")
    [[ "$HTTP_CODE" =~ ^[23] ]] && log "Panel responde HTTP ${HTTP_CODE}" || warn "Panel no responde (HTTP ${HTTP_CODE})"

    if [[ -n "${PANEL_DOMAIN:-}" ]]; then
        HTTPS_CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 10 "https://${PANEL_DOMAIN}/" 2>/dev/null || echo "000")
        [[ "$HTTPS_CODE" =~ ^[23] ]] && log "HTTPS ${PANEL_DOMAIN}: OK (${HTTPS_CODE})" || warn "HTTPS ${PANEL_DOMAIN}: ${HTTPS_CODE}"
    fi
fi

# Backups
BACKUP_COUNT=$(find "${ROOT}/backups" -name 'vpn-backup-*.tar.gz' 2>/dev/null | wc -l)
info "Backups disponibles: ${BACKUP_COUNT}"

# Healthcheck integrado
echo ""
"${ROOT}/scripts/healthcheck.sh" 2>/dev/null || true

echo ""
log "Diagnóstico completado"
