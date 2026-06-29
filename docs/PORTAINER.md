# Desplegar VP´N en Portainer

## Error común

```
WG_HOST is missing a value: WG_HOST es obligatorio
```

Significa que **no configuraste las variables de entorno** antes de desplegar.

---

## Error: puerto 8443 already in use

Portainer guarda variables antiguas. **Elimina** `WEB_PORT=8443` de Environment variables
(o cámbiala a `51822`). El compose ya usa **51822 fijo** — no hace falta definir `WEB_PORT`.

Si sigue fallando, borra contenedores viejos:

```bash
docker rm -f vpn-portal 2>/dev/null
docker compose down
```

---

## Paso 1 — Variables obligatorias

En Portainer: **Stacks** → tu stack → **Editor** → sección **Environment variables**

Añade estas (cambia los valores):

| Variable | Ejemplo | Descripción |
|---|---|---|
| `WG_HOST` | `203.0.113.45` | IP pública de tu servidor |
| `ADMIN_PASSWORD` | `MiClaveSegura123!` | Contraseña del panel (mín. 8) |
| `JWT_SECRET` | `a1b2c3...` (64 chars) | `openssl rand -hex 32` en el servidor |

Opcionales (tienen default):

| Variable | Default | Notas |
|---|---|---|
| `WG_PORT` | `443` | VPN UDP |
| `VPN_MODE` | `gaming` | |
| `ADMIN_USER` | `admin` | |
| Panel web | **51822/TCP** | Fijado en compose — no uses `WEB_PORT=8443` |

Plantilla lista para copiar: [portainer.env.example](../portainer.env.example)

---

## Paso 2 — Desplegar el stack

**Opción A — Desde Git**

1. Stacks → Add stack  
2. Repository URL: `https://github.com/IgnacioLondono/vpn.git`  
3. Compose path: `docker-compose.yml`  
4. Añade las **Environment variables** del paso 1  
5. Deploy  

**Opción B — Con archivo .env en el servidor**

```bash
git clone https://github.com/IgnacioLondono/vpn.git
cd vpn
cp .env.example .env
nano .env   # rellena WG_HOST, ADMIN_PASSWORD, JWT_SECRET
docker compose up -d --build
```

---

## Paso 3 — Abrir puertos en el firewall

```bash
sudo ufw allow 443/udp    # VPN WireGuard
sudo ufw allow 51822/tcp   # Panel web
```

Panel: `http://TU_IP:51822`

---

## Auto-detectar IP

Si dejas `WG_HOST` vacío, el contenedor intenta detectar la IP pública al arrancar. **Recomendado:** configúrala manualmente para evitar sorpresas.

---

## Generar JWT_SECRET en el servidor

```bash
openssl rand -hex 32
```

Copia el resultado en la variable `JWT_SECRET` de Portainer.
