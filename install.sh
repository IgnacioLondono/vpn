#!/usr/bin/env bash
# Instalador universal VP´N — punto de entrada único
# Uso: curl -fsSL .../install.sh | sudo bash
#      sudo ./install.sh [--prod]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MODE="${1:-standard}"

main() {
    echo ""
    echo "  VP´N WireGuard VPN — Instalador"
    echo "  ================================"
    echo ""

    chmod +x "${SCRIPT_DIR}/scripts/"*.sh 2>/dev/null || true
    chmod +x "${SCRIPT_DIR}/scripts/lib/"*.sh 2>/dev/null || true

    case "$MODE" in
        --prod|--production)
            "${SCRIPT_DIR}/scripts/install-server.sh"
            "${SCRIPT_DIR}/scripts/deploy-prod.sh"
            ;;
        *)
            "${SCRIPT_DIR}/scripts/install-server.sh"
            ;;
    esac
}

main "$@"
