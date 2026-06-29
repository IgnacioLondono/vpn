#!/usr/bin/env bash
# Biblioteca compartida de funciones para scripts VP´N

set -euo pipefail

VPN_VERSION="1.0.0"
VPN_NAME="VP´N"

# Colores (deshabilitados si NO_COLOR está definido)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
    C_RED='\033[0;31m'
    C_GREEN='\033[0;32m'
    C_YELLOW='\033[1;33m'
    C_BLUE='\033[0;34m'
    C_BOLD='\033[1m'
    C_NC='\033[0m'
else
    C_RED='' C_GREEN='' C_YELLOW='' C_BLUE='' C_BOLD='' C_NC=''
fi

log()   { echo -e "${C_GREEN}[VPN]${C_NC} $*"; }
info()  { echo -e "${C_BLUE}[INFO]${C_NC} $*"; }
warn()  { echo -e "${C_YELLOW}[AVISO]${C_NC} $*"; }
error() { echo -e "${C_RED}[ERROR]${C_NC} $*" >&2; }
die()   { error "$*"; exit 1; }

banner() {
    echo -e "${C_BOLD}"
    echo "  ╔══════════════════════════════════════╗"
    echo "  ║           VP´N WireGuard VPN         ║"
    echo "  ║              v${VPN_VERSION}                   ║"
    echo "  ╚══════════════════════════════════════╝"
    echo -e "${C_NC}"
}

# Resuelve directorio raíz del proyecto
project_root() {
    local script_dir
    script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    if [[ "$(basename "$script_dir")" == "lib" ]]; then
        dirname "$(dirname "$script_dir")"
    elif [[ "$(basename "$script_dir")" == "scripts" ]]; then
        dirname "$script_dir"
    else
        echo "$script_dir"
    fi
}

load_env() {
    local root="${1:-}"
    local env_file="${root}/.env"
    [[ -f "$env_file" ]] || die "No existe ${env_file}. Copia .env.example a .env"
    set -a
    # shellcheck disable=SC1090
    source "$env_file"
    set +a
}

require_root() {
    [[ $EUID -eq 0 ]] || die "Este comando requiere privilegios root: sudo $*"
}

require_docker() {
    command -v docker &>/dev/null || die "Docker no está instalado"
    docker info &>/dev/null || die "Docker no está en ejecución"
}

detect_public_ip() {
    curl -4 -s --max-time 5 ifconfig.me 2>/dev/null \
        || curl -4 -s --max-time 5 icanhazip.com 2>/dev/null \
        || echo ""
}

is_valid_ip() {
    local ip="$1"
    [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]
}

is_valid_domain() {
    local domain="$1"
    [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z]{2,})+$ ]]
}

generate_password_hash() {
    local password="$1"
    docker run --rm ghcr.io/wg-easy/wg-easy wgpw "$password" 2>/dev/null | tr -d '\r\n'
}

compose_cmd() {
    local root="$1"
    shift
    local files=(-f "${root}/docker-compose.yml")
    local profiles=()

    [[ -f "${root}/.env" ]] && load_env "$root" 2>/dev/null || true

    if [[ "${VPN_DEPLOY_MODE:-}" == "prod" ]]; then
        files+=(-f "${root}/docker-compose.prod.yml")
    fi
    if [[ "${VPN_DEPLOY_MODE:-}" == "ssl" || "${VPN_DEPLOY_MODE:-}" == "prod-ssl" ]]; then
        files+=(-f "${root}/docker-compose.ssl.yml")
        profiles+=(--profile ssl)
    fi
    if [[ "${VPN_ENABLE_WATCHTOWER:-false}" == "true" ]]; then
        profiles+=(--profile watchtower)
    fi

    (cd "$root" && docker compose "${files[@]}" "${profiles[@]}" "$@")
}

timestamp() {
    date +%Y%m%d_%H%M%S
}

confirm() {
    local prompt="${1:-¿Continuar?}"
    read -r -p "${prompt} [s/N] " reply
    [[ "$reply" =~ ^[sS]$ ]]
}
