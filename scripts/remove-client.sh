#!/usr/bin/env bash
# Elimina un cliente WireGuard (instalación manual sin panel)
# Uso: sudo ./scripts/remove-client.sh <nombre|ip>

set -euo pipefail
source "$(dirname "$0")/lib/common.sh"

CLIENT="${1:-}"
WG_CONF="/etc/wireguard/wg0.conf"

require_root "$0"
[[ -n "$CLIENT" ]] || die "Uso: $0 <nombre-cliente|10.8.0.x>"

[[ -f "$WG_CONF" ]] || die "No existe ${WG_CONF}"

if [[ "$CLIENT" =~ ^10\.8\.0\.[0-9]+$ ]]; then
    PATTERN="AllowedIPs = ${CLIENT}/32"
else
    PATTERN="# ${CLIENT}"
fi

grep -q "$PATTERN" "$WG_CONF" || die "Cliente no encontrado: ${CLIENT}"

# Eliminar bloque [Peer] (desde comentario o PublicKey hasta AllowedIPs)
TEMP=$(mktemp)
awk -v client="$CLIENT" '
    /^\[Peer\]/ { in_peer=1; block=$0"\n"; next }
    in_peer {
        block=block $0"\n"
        if (/AllowedIPs/) {
            if (block ~ client || block ~ ("# " client)) { in_peer=0; block=""; next }
            print block; in_peer=0; block=""
        }
        next
    }
    { print }
' "$WG_CONF" > "$TEMP"

mv "$TEMP" "$WG_CONF"
wg syncconf wg0 <(wg-quick strip wg0) 2>/dev/null || true

log "Cliente '${CLIENT}' eliminado"
