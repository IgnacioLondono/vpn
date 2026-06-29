#!/usr/bin/env bash
# Restaura backup de configuración VPN
# Uso: ./scripts/restore.sh /ruta/vpn-backup-YYYYMMDD_HHMMSS.tar.gz

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ARCHIVE="${1:-}"
ROOT="$(project_root)"

[[ -n "$ARCHIVE" && -f "$ARCHIVE" ]] || die "Uso: $0 <archivo-backup.tar.gz>"

banner
warn "Esta operación sobrescribirá la configuración actual."
confirm "¿Restaurar desde ${ARCHIVE}?" || exit 0

require_docker

# Backup de seguridad previo
if [[ -d "${ROOT}/data/wg-easy" ]]; then
    PRE_BACKUP="${ROOT}/backups/pre-restore-$(timestamp).tar.gz"
    mkdir -p "${ROOT}/backups"
    (cd "$ROOT" && tar -czf "$PRE_BACKUP" data/wg-easy .env 2>/dev/null) || true
    info "Backup previo: ${PRE_BACKUP}"
fi

log "Deteniendo servicios..."
VPN_DEPLOY_MODE="${VPN_DEPLOY_MODE:-}" compose_cmd "$ROOT" down 2>/dev/null || true

log "Restaurando archivos..."
tar -xzf "$ARCHIVE" -C "$ROOT"

log "Reiniciando servicios..."
compose_cmd "$ROOT" up -d

log "Restauración completada"
compose_cmd "$ROOT" ps
