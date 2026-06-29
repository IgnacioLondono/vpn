#!/usr/bin/env bash
# Despliegue en modo producción con HTTPS (Caddy + Let's Encrypt)
# Uso: sudo ./scripts/deploy-prod.sh

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root "$0"
ROOT="$(project_root)"
load_env "$ROOT"

banner

./scripts/validate-env.sh --ssl

[[ -n "${PANEL_DOMAIN:-}" ]] || die "Configura PANEL_DOMAIN en .env"
[[ -n "${ACME_EMAIL:-}" ]] || die "Configura ACME_EMAIL en .env"

log "Verificando DNS de ${PANEL_DOMAIN}..."
RESOLVED=$(dig +short "$PANEL_DOMAIN" 2>/dev/null | tail -1 || echo "")
PUBLIC_IP=$(detect_public_ip)

if [[ -n "$RESOLVED" && -n "$PUBLIC_IP" && "$RESOLVED" != "$PUBLIC_IP" ]]; then
    warn "DNS (${RESOLVED}) no coincide con IP pública (${PUBLIC_IP})"
    confirm "¿Continuar de todos modos?" || exit 1
fi

mkdir -p "${ROOT}/data/wg-easy" "${ROOT}/backups"

log "Backup previo al despliegue..."
./scripts/backup.sh

export VPN_DEPLOY_MODE=prod-ssl
export VPN_ENABLE_WATCHTOWER="${VPN_ENABLE_WATCHTOWER:-true}"

log "Desplegando stack producción (SSL + Watchtower)..."
compose_cmd "$ROOT" up -d --remove-orphans

sleep 5
compose_cmd "$ROOT" ps

echo ""
log "Despliegue completado"
echo "  Panel HTTPS: https://${PANEL_DOMAIN}"
echo "  WireGuard:   ${WG_HOST}:${WG_PORT:-51820}/udp"
echo ""
info "El certificado SSL puede tardar 1-2 minutos en emitirse"
