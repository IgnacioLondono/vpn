#!/bin/bash
set -e

echo "[entrypoint] Iniciando VP´N Portal..."

detect_public_ip() {
  curl -4 -s --max-time 5 ifconfig.me 2>/dev/null \
    || curl -4 -s --max-time 5 icanhazip.com 2>/dev/null \
    || echo ""
}

# Auto-detectar IP pública si WG_HOST vacío (útil en Portainer / primer despliegue)
if [ -z "${WG_HOST:-}" ]; then
  DETECTED=$(detect_public_ip)
  if [ -n "$DETECTED" ]; then
    export WG_HOST="$DETECTED"
    echo "[entrypoint] WG_HOST auto-detectado: $WG_HOST"
  else
    echo "[ERROR] WG_HOST no configurado."
    echo "  Añade en .env o en Portainer → Stack → Environment variables:"
    echo "    WG_HOST=tu.ip.publica"
    exit 1
  fi
fi

if [ -z "${ADMIN_PASSWORD:-}" ]; then
  echo "[ERROR] ADMIN_PASSWORD no configurado (mínimo 8 caracteres)."
  exit 1
fi

if [ -z "${JWT_SECRET:-}" ] || [ "${#JWT_SECRET}" -lt 32 ]; then
  echo "[ERROR] JWT_SECRET no configurado o demasiado corto."
  echo "  Genera uno: openssl rand -hex 32"
  exit 1
fi

sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sysctl -w net.ipv4.conf.all.src_valid_mark=1 2>/dev/null || true

mkdir -p /etc/wireguard /data
chmod 700 /etc/wireguard

if [ -f /etc/wireguard/wg0.conf ]; then
  wg-quick down wg0 2>/dev/null || true
  wg-quick up wg0 2>/dev/null || echo "[entrypoint] WireGuard se iniciará vía API"
fi

echo "[entrypoint] WG_HOST=$WG_HOST | WEB_PORT=${WEB_PORT:-51822} | VPN UDP ${WG_PORT:-443}"
exec node src/index.js
