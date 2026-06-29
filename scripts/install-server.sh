#!/usr/bin/env bash
# Instalación del portal VP´N en Linux
set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

require_root "$0"
ROOT="$(project_root)"
banner

install_docker() {
    command -v docker &>/dev/null && { log "Docker OK"; return; }
    apt-get update -qq && apt-get install -y -qq curl
    curl -fsSL https://get.docker.com | sh
    systemctl enable --now docker
}

enable_ip_forwarding() {
    cat > /etc/sysctl.d/99-vpn.conf << 'EOF'
net.ipv4.ip_forward=1
net.ipv4.conf.all.src_valid_mark=1
EOF
    sysctl --system >/dev/null 2>&1
}

setup_env() {
    [[ -f "${ROOT}/.env" ]] && return
    cp "${ROOT}/.env.example" "${ROOT}/.env"
    ip="$(detect_public_ip)"
    [[ -n "$ip" ]] && sed -i "s/^WG_HOST=$/WG_HOST=${ip}/" "${ROOT}/.env"
    jwt="$(openssl rand -hex 32 2>/dev/null || head -c 32 /dev/urandom | xxd -p -c 64)"
    sed -i "s/^JWT_SECRET=$/JWT_SECRET=${jwt}/" "${ROOT}/.env"
    warn "Configura ADMIN_PASSWORD en .env antes de iniciar"
}

start_stack() {
    cd "$ROOT"
    mkdir -p data/wireguard data/portal backups
    chmod +x scripts/*.sh web/entrypoint.sh

    if ! grep -q '^ADMIN_PASSWORD=.\+' .env 2>/dev/null; then
        warn "Define ADMIN_PASSWORD en .env → make start"
        return
    fi

    "${ROOT}/scripts/validate-env.sh"
    docker compose up -d --build
    docker compose ps
}

install_docker
apt-get install -y -qq wireguard-tools make openssl 2>/dev/null || true
enable_ip_forwarding
setup_env
start_stack

load_env "$ROOT" 2>/dev/null || true
echo ""
log "Portal listo: http://${WG_HOST:-localhost}:${WEB_PORT:-51822}"
log "Usuario: ${ADMIN_USER:-admin}"
