#!/usr/bin/env bash
# Actualiza imágenes Docker y reinicia el stack de forma segura
# Uso: ./scripts/update.sh

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ROOT="$(project_root)"
require_docker

banner
load_env "$ROOT" 2>/dev/null || true

log "Creando backup antes de actualizar..."
"${ROOT}/scripts/backup.sh"

log "Descargando imágenes actualizadas..."
docker compose -f "${ROOT}/docker-compose.yml" pull

log "Recreando contenedores..."
compose_cmd "$ROOT" up -d --remove-orphans

log "Limpiando imágenes obsoletas..."
docker image prune -f

compose_cmd "$ROOT" ps
log "Actualización completada"
