# Portal web VP´N

## Despliegue en tu nube Linux

### Requisitos

- Ubuntu 22.04+ / Debian 11+
- Docker + Docker Compose
- IP pública
- Puertos: **UDP 443** (VPN), **TCP 8443** (portal) o **443** (panel con HTTPS)

### Paso 1 — Configurar

```bash
cp .env.example .env
```

Edita `.env`:

```env
WG_HOST=203.0.113.45          # Tu IP pública
ADMIN_USER=admin
ADMIN_PASSWORD=TuClaveSegura123!
JWT_SECRET=abc123...            # openssl rand -hex 32
WEB_PORT=8443
```

### Paso 2 — Instalar

```bash
sudo ./scripts/install-server.sh
# o
make start
```

### Paso 3 — Usar el panel

1. Abre `http://WG_HOST:8443`
2. Inicia sesión con `ADMIN_USER` / `ADMIN_PASSWORD`
3. Pulsa **Registrar este PC**
4. Pulsa **Encender VPN en este PC**

Solo ese dispositivo tendrá tráfico enrutado por la VPN.

## Agente Windows

El agente sincroniza el estado del panel con WireGuard en tu PC:

| Estado en panel | Efecto en PC |
|---|---|
| Encendido | WireGuard conectado, `AllowedIPs = 0.0.0.0/0` |
| Apagado | WireGuard desconectado, sin efecto |
| Otro PC encendido | Este PC permanece desconectado |

```powershell
.\scripts\vpn-agent.ps1 -ServerUrl "https://vpn.tudominio.com" -AgentToken "UUID"
```

El token aparece al registrar el dispositivo (también en `localStorage.vpn_agent_token`).

## HTTPS

1. Apunta un registro DNS `A` de `vpn.tudominio.com` a tu servidor
2. Configura en `.env`:
   ```env
   PANEL_DOMAIN=vpn.tudominio.com
   ACME_EMAIL=tu@email.com
   ```
3. Inicia con Caddy:
   ```bash
   docker compose --profile ssl up -d --build
   ```

## API

| Método | Ruta | Descripción |
|---|---|---|
| POST | `/api/auth/login` | Iniciar sesión |
| GET | `/api/devices` | Listar dispositivos |
| POST | `/api/devices/register` | Registrar dispositivo |
| POST | `/api/devices/:id/activate` | Encender VPN (solo este) |
| POST | `/api/devices/:id/deactivate` | Apagar VPN |
| GET | `/api/agent/status` | Estado para agente (header `X-Agent-Token`) |

## Solución de problemas

| Problema | Solución |
|---|---|
| Portal no carga | `docker compose logs vpn-portal` |
| VPN no conecta | Abre UDP 51820 en firewall cloud |
| Agente no reacciona | Verifica token y URL del servidor |
| Otro PC sigue con VPN | Solo uno activo; apaga desde panel o enciende en el otro |
