#!/usr/bin/env bash
# Backup de configuración WireGuard y .env
# Uso: ./scripts/backup.sh [--output /ruta/backups]

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ROOT="$(project_root)"
BACKUP_DIR="${1:-${ROOT}/backups}"
RETENTION="${BACKUP_RETENTION_DAYS:-30}"
STAMP="$(timestamp)"
ARCHIVE="${BACKUP_DIR}/vpn-backup-${STAMP}.tar.gz"

mkdir -p "$BACKUP_DIR"

load_env "$ROOT" 2>/dev/null || true

log "Creando backup en ${ARCHIVE}..."

tar_args=()
[[ -f "${ROOT}/.env" ]] && tar_args+=(".env")
[[ -d "${ROOT}/data/wireguard" ]] && tar_args+=("data/wireguard")
[[ -d "${ROOT}/data/portal" ]] && tar_args+=("data/portal")
[[ -d "${ROOT}/clients" ]] && tar_args+=("clients")

if [[ ${#tar_args[@]} -eq 0 ]]; then
    die "No hay datos para respaldar"
fi

(cd "$ROOT" && tar -czf "$ARCHIVE" "${tar_args[@]}")
chmod 600 "$ARCHIVE"

SIZE=$(du -h "$ARCHIVE" | cut -f1)
log "Backup creado: ${ARCHIVE} (${SIZE})"

# Rotación
if [[ "$RETENTION" =~ ^[0-9]+$ && "$RETENTION" -gt 0 ]]; then
    find "$BACKUP_DIR" -name 'vpn-backup-*.tar.gz' -mtime +"$RETENTION" -delete 2>/dev/null || true
    info "Backups anteriores a ${RETENTION} días eliminados"
fi

echo "$ARCHIVE"
