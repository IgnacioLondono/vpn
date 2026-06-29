#!/bin/bash
set -e

echo "[entrypoint] Iniciando VP´N Portal..."

sysctl -w net.ipv4.ip_forward=1 2>/dev/null || true
sysctl -w net.ipv4.conf.all.src_valid_mark=1 2>/dev/null || true

mkdir -p /etc/wireguard /data
chmod 700 /etc/wireguard

# Levantar WireGuard si existe configuración
if [ -f /etc/wireguard/wg0.conf ]; then
  wg-quick down wg0 2>/dev/null || true
  wg-quick up wg0 2>/dev/null || echo "[entrypoint] WireGuard se iniciará vía API"
fi

exec node src/index.js
