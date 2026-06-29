# Guía de instalación del servidor VPN

## Requisitos

| Componente | Mínimo |
|---|---|
| SO servidor | Ubuntu 22.04+ / Debian 11+ / cualquier Linux con Docker |
| RAM | 512 MB |
| CPU | 1 vCPU |
| Red | IP pública + puerto UDP 51820 abierto |
| Cliente Windows | Windows 10/11 + WireGuard |

## Opción A: Instalación automática (recomendada)

En tu VPS Linux:

```bash
git clone <tu-repo> vpn && cd vpn
chmod +x scripts/*.sh
sudo ./scripts/install-server.sh
```

El script instala Docker, WireGuard, configura IP forwarding, crea `.env` y levanta el stack.

### Configurar contraseña del panel

Antes de que funcione el panel web, genera el hash de contraseña:

```bash
docker run --rm ghcr.io/wg-easy/wg-easy wgpw 'TuContraseñaSegura123!'
```

Copia el hash en `.env` → `WG_PASSWORD_HASH=...` y reinicia:

```bash
docker compose restart
```

## Opción B: Desde Windows con Docker Desktop

```powershell
cd "C:\Users\ignac\Desktop\VP´N"
copy .env.example .env
# Edita .env: WG_HOST con tu IP pública

.\scripts\manage-server.ps1 -Action password -Password "TuContraseñaSegura123!"
.\scripts\manage-server.ps1 -Action start
```

## Firewall del servidor

Abre estos puertos en tu proveedor cloud (AWS Security Group, Hetzner, etc.) y en el firewall local:

| Puerto | Protocolo | Uso |
|---|---|---|
| 51820 | UDP | Tráfico VPN WireGuard |
| 51821 | TCP | Panel web de administración |

### UFW (Ubuntu)

```bash
sudo ufw allow 51820/udp
sudo ufw allow 51821/tcp
sudo ufw reload
```

### iptables

```bash
iptables -A INPUT -p udp --dport 51820 -j ACCEPT
iptables -A INPUT -p tcp --dport 51821 -j ACCEPT
```

## Crear clientes

### Con panel web (wg-easy)

1. Abre `http://TU_IP:51821`
2. Inicia sesión con tu contraseña
3. Pulsa **+ Nuevo** para crear un cliente
4. Descarga el `.conf` o escanea el código QR (móvil)

### Manualmente (sin panel)

```bash
sudo ./scripts/add-client.sh mi-portatil
# Genera clients/mi-portatil.conf
```

## Conectar desde Windows

```powershell
.\scripts\install-client.ps1 -ConfigPath ".\clients\mi-portatil.conf" -Connect
```

O instala [WireGuard para Windows](https://www.wireguard.com/install/) e importa el `.conf` manualmente.

## Verificar que funciona

```bash
./scripts/check-vpn.sh
```

Desde el cliente conectado:

```powershell
# Debe mostrar la IP del servidor VPN
curl ifconfig.me
```

## Solución de problemas

| Problema | Solución |
|---|---|
| No conecta | Verifica UDP 51820 abierto en cloud + UFW |
| Sin internet en cliente | Comprueba `net.ipv4.ip_forward=1` en el servidor |
| Panel no carga | Verifica TCP 51821 y `WG_PASSWORD_HASH` en `.env |
| MTU / páginas lentas | Reduce `WG_MTU=1280` en `.env` |
| Split tunnel | Cambia `WG_ALLOWED_IPS=192.168.1.0/24` en `.env` |

## Arquitectura

```
[Cliente Windows/Android]
        │ UDP 51820 (cifrado WireGuard)
        ▼
[Servidor VPS - Docker]
  ┌─────────────────────┐
  │  wg-easy (panel)    │ :51821 TCP
  │  WireGuard (wg0)    │ :51820 UDP
  │  NAT / IP forward   │
  └─────────────────────┘
        │
        ▼
   Internet / LAN
```
