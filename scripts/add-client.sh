#!/usr/bin/env bash
# Añade un cliente WireGuard manualmente (sin panel web)
# Uso: sudo ./scripts/add-client.sh nombre-cliente

set -euo pipefail

CLIENT_NAME="${1:-}"
WG_CONF="/etc/wireguard/wg0.conf"
CLIENTS_DIR="./clients"

[[ $EUID -ne 0 ]] && { echo "Ejecuta como root: sudo $0 <nombre>"; exit 1; }
[[ -z "$CLIENT_NAME" ]] && { echo "Uso: sudo $0 <nombre-cliente>"; exit 1; }
[[ ! -f "$WG_CONF" ]] && { echo "No existe $WG_CONF. Configura el servidor primero."; exit 1; }

mkdir -p "$CLIENTS_DIR"

# Obtener siguiente IP disponible (10.8.0.2 - 10.8.0.254)
LAST_IP=$(grep -oP 'AllowedIPs = 10\.8\.0\.\K[0-9]+' "$WG_CONF" 2>/dev/null | sort -n | tail -1 || echo "1")
NEXT_IP=$((LAST_IP + 1))
[[ $NEXT_IP -gt 254 ]] && { echo "No hay IPs disponibles"; exit 1; }

CLIENT_IP="10.8.0.${NEXT_IP}"

# Generar claves
CLIENT_PRIV=$(wg genkey)
CLIENT_PUB=$(echo "$CLIENT_PRIV" | wg pubkey)

# Obtener clave pública del servidor
SERVER_PUB=$(grep -m1 PrivateKey "$WG_CONF" | awk '{print $3}' | wg pubkey)
SERVER_ENDPOINT=$(grep -m1 ListenPort "$WG_CONF" | awk '{print $3}')
SERVER_IP=$(curl -4 -s ifconfig.me 2>/dev/null || echo "TU_SERVIDOR_IP")

# Añadir peer al servidor
cat >> "$WG_CONF" << EOF

[Peer]
# ${CLIENT_NAME}
PublicKey = ${CLIENT_PUB}
AllowedIPs = ${CLIENT_IP}/32
EOF

wg syncconf wg0 <(wg-quick strip wg0)

# Generar config del cliente
CLIENT_FILE="${CLIENTS_DIR}/${CLIENT_NAME}.conf"
cat > "$CLIENT_FILE" << EOF
[Interface]
PrivateKey = ${CLIENT_PRIV}
Address = ${CLIENT_IP}/32
DNS = 1.1.1.1, 8.8.8.8

[Peer]
PublicKey = ${SERVER_PUB}
Endpoint = ${SERVER_IP}:${SERVER_ENDPOINT}
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
EOF

chmod 600 "$CLIENT_FILE"
echo "Cliente '${CLIENT_NAME}' creado: ${CLIENT_FILE} (IP: ${CLIENT_IP})"
