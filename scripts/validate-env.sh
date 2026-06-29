#!/usr/bin/env bash
# Valida .env para el portal VP´N
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

ROOT="$(project_root)"
ENV_FILE="${ROOT}/.env"
ERRORS=0

check() { [[ "$1" == "true" ]] && log "✓ $2" || { error "$2"; ERRORS=$((ERRORS+1)); }; }

[[ -f "$ENV_FILE" ]] || die "Crea .env: cp .env.example .env"
load_env "$ROOT"

banner

[[ -n "${WG_HOST:-}" ]] && check true "WG_HOST=${WG_HOST}" || check false "WG_HOST obligatorio"
[[ -n "${ADMIN_PASSWORD:-}" && ${#ADMIN_PASSWORD} -ge 8 ]] && check true "ADMIN_PASSWORD configurado" || check false "ADMIN_PASSWORD mínimo 8 caracteres"
[[ -n "${JWT_SECRET:-}" && ${#JWT_SECRET} -ge 32 ]] && check true "JWT_SECRET configurado" || check false "JWT_SECRET mínimo 32 chars (openssl rand -hex 32)"

[[ $ERRORS -eq 0 ]] && log "Validación OK" || die "${ERRORS} error(es)"
exit $ERRORS
