# ¿Es gratis? Modo juegos y un solo puerto

## ¿Cuánto cuesta?

| Concepto | Coste |
|---|---|
| **VP´N (software)** | **Gratis** — WireGuard y el portal son open source |
| **Tu nube Linux** | Lo que ya pagues por tu VPS/servidor (Hetzner, Oracle Free Tier, etc.) |
| **Suscripción VPN comercial** | **No hace falta** — es tu propio servidor |

Si ya tienes un servidor Linux en la nube, **no pagas nada extra** por usar VP´N.

---

## Un solo puerto

Solo necesitas abrir **un puerto UDP** para la VPN:

```env
WG_PORT=443
```

- **443/UDP** — tráfico WireGuard (VPN). Suele pasar mejor routers y firewalls.
- El panel web usa **51822/TCP** (o **443/TCP** con HTTPS vía Caddy).

En el firewall de tu nube:

```bash
sudo ufw allow 443/udp comment 'VP´N WireGuard'
sudo ufw allow 51822/tcp comment 'Panel VP´N'
```

---

## Modo juegos (por defecto) — no te expulsa de partidas

```env
VPN_MODE=gaming
```

Con este modo, cuando enciendes la VPN desde el panel:

- El túnel WireGuard **se conecta** (escudo activo, keepalive cada 15 s).
- El tráfico de **juegos online NO pasa por la VPN** — va directo a tus servidores de juego.
- Resultado: **menos lag, menos expulsiones**, sin “acceso denegado” por IP de VPN en anti-cheat.

Cuando apagas la VPN desde el panel, el túnel se desconecta por completo.

### Estabilidad anti-pérdida de paquetes

```env
WG_MTU=1280              # Evita fragmentación en redes problemáticas
WG_PERSISTENT_KEEPALIVE=15   # Mantiene el túnel vivo tras NAT/firewall
```

En el servidor Linux (opcional, mejora estabilidad):

```bash
# Activar BBR (mejor rendimiento en redes con pérdida)
echo "net.core.default_qdisc=fq" | sudo tee -a /etc/sysctl.d/99-vpn.conf
echo "net.ipv4.tcp_congestion_control=bbr" | sudo tee -a /etc/sysctl.d/99-vpn.conf
sudo sysctl --system
```

---

## Modo completo (solo si lo necesitas)

```env
VPN_MODE=full
```

Enruta **todo** el tráfico por la VPN (`0.0.0.0/0`). Útil para privacidad o saltar bloqueos, pero **peor para juegos online** (más ping, riesgo de kick).

---

## Resumen práctico para jugar

1. Deja `VPN_MODE=gaming` (predeterminado).
2. Usa `WG_PORT=443` — un solo puerto UDP.
3. **Apaga la VPN** desde el panel mientras juegas competivo si quieres el ping mínimo.
4. **Enciéndela** cuando no juegas o quieras el escudo activo en ese PC.

---

## Lo que VP´N no hace

- No es un anti-DDoS comercial como servicios de gaming VPN de pago.
- No garantiza mejor ruta a servidores de juego (depende de dónde esté tu nube).
- No sustituye un buen ISP; ayuda con túnel estable y control por dispositivo.
