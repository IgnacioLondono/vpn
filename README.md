# VP´N — VPN personal con portal web

Portal web propio para controlar tu VPN WireGuard en tu nube Linux. **Gratis** (solo pagas tu servidor si lo tienes). **Un puerto UDP**. **Modo juegos** para no ser expulsado de partidas.

## ¿Es gratis?

**Sí.** El software es gratuito y open source. Solo pagas tu nube Linux si ya la tienes contratada (VPS, Oracle Free Tier, etc.). No necesitas suscripción a NordVPN ni similar.

## Modo juegos + un puerto

| Ajuste | Valor | Para qué |
|---|---|---|
| `WG_PORT` | `443` | Un solo puerto UDP (VPN) |
| `VPN_MODE` | `gaming` | Túnel activo **sin** reenrutar juegos |
| `WG_MTU` | `1280` | Menos pérdida de paquetes |
| `WG_PERSISTENT_KEEPALIVE` | `15` | Túnel estable tras NAT |

Detalle completo: [docs/GAMING.md](docs/GAMING.md) · Portainer: [docs/PORTAINER.md](docs/PORTAINER.md)

## Cómo funciona

```
┌─────────────┐     Encender VPN      ┌──────────────────┐
│  Tu PC #1   │ ───────────────────►  │  Portal web      │
│  (activo)   │ ◄── config 0.0.0.0/0 ─│  (tu nube Linux) │
└─────────────┘                       └────────┬─────────┘
                                               │
┌─────────────┐     Standby / apagado          │ WireGuard
│  Tu PC #2   │ ◄── sin tráfico VPN ───────────┘
└─────────────┘
```

- **Un solo dispositivo activo** a la vez: si enciendes la VPN en otro PC, el anterior se desactiva.
- **Agente Windows** (opcional): conecta/desconecta WireGuard automáticamente al pulsar el botón en la web.

## Inicio rápido (nube Linux)

```bash
git clone https://github.com/IgnacioLondono/vpn.git && cd vpn
cp .env.example .env
nano .env   # ADMIN_PASSWORD, WG_HOST (tu IP pública)

chmod +x install.sh scripts/*.sh
sudo ./install.sh
```

Abre `http://TU_IP:8443` → inicia sesión → **Registrar este PC** → **Encender VPN en este PC**.

## Configuración (.env)

| Variable | Descripción |
|---|---|
| `WG_HOST` | IP o dominio público del servidor |
| `WEB_PORT` | Puerto del portal (**8443** TCP) |
| `ADMIN_USER` | Usuario del panel |
| `ADMIN_PASSWORD` | Contraseña (mín. 8 caracteres) |
| `JWT_SECRET` | Secreto JWT (`openssl rand -hex 32`) |
| `PANEL_DOMAIN` | Dominio HTTPS (opcional) |

## Agente Windows (recomendado)

Tras registrar el PC en el panel, copia el **Agent Token** y ejecuta en PowerShell como administrador:

```powershell
cd scripts
.\vpn-agent.ps1 -ServerUrl "http://TU_IP:8443" -AgentToken "tu-token-aqui"
```

Para iniciar automáticamente al encender Windows:

```powershell
.\vpn-agent.ps1 -Install -ServerUrl "http://TU_IP:8443" -AgentToken "tu-token"
```

## HTTPS con dominio propio

```bash
# En .env: PANEL_DOMAIN=vpn.tudominio.com, ACME_EMAIL=tu@email.com
docker compose --profile ssl up -d
```

## Estructura

```
VP´N/
├── web/
│   ├── frontend/     # React — panel web
│   ├── backend/      # API Node.js + WireGuard
│   └── Dockerfile
├── scripts/
│   ├── vpn-agent.ps1 # Agente Windows
│   └── install-server.sh
├── docker-compose.yml
└── docs/WEB.md
```

## Comandos

```bash
make init          # Crear .env
make start         # Construir e iniciar
make logs          # Ver logs
make backup        # Backup config + BD
make health        # Healthcheck
```

## Seguridad

- Cambia `ADMIN_PASSWORD` y `JWT_SECRET` antes de desplegar.
- Usa HTTPS en producción (`--profile ssl`).
- Restringe el puerto **8443/TCP** con firewall a tus IPs si no usas HTTPS.
- No compartas el Agent Token ni archivos `.conf`.

Documentación detallada: [docs/WEB.md](docs/WEB.md)
