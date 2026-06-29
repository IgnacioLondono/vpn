#!/usr/bin/env bash
# Desinstala el stack VPN (conserva datos en data/ y backups/)
# Uso: sudo ./scripts/uninstall.sh [--purge]

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

PURGE=false
[[ "${1:-}" == "--purge" ]] && PURGE=true

require_root "$0"
ROOT="$(project_root)"

banner
warn "Se detendrán y eliminarán los contenedores VPN."
[[ "$PURGE" == "true" ]] && warn "Modo --purge: también se borrarán data/ y backups/"

confirm "¿Desinstalar VP´N?" || exit 0

load_env "$ROOT" 2>/dev/null || true

log "Backup final..."
"${ROOT}/scripts/backup.sh" 2>/dev/null || true

log "Deteniendo contenedores..."
docker compose -f "${ROOT}/docker-compose.yml" --profile ssl --profile watchtower down -v 2>/dev/null || \
    docker compose -f "${ROOT}/docker-compose.yml" down -v 2>/dev/null || true

if [[ "$PURGE" == "true" ]]; then
    rm -rf "${ROOT}/data/wg-easy" "${ROOT}/backups"
    warn "Datos eliminados"
else
    info "Datos conservados en data/ y backups/"
fi

log "Desinstalación completada"
