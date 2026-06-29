# VP´N Portal — imagen Docker (Web + API + WireGuard)
FROM node:20-alpine AS frontend-build
WORKDIR /build/web/frontend
COPY web/frontend/package.json ./
RUN npm install
COPY web/frontend/ ./
RUN npm run build

FROM node:20-alpine
RUN apk add --no-cache wireguard-tools iptables bash curl
WORKDIR /app
COPY web/backend/package.json ./
RUN npm install --omit=dev
COPY web/backend/ ./
COPY --from=frontend-build /build/web/backend/public ./public
COPY web/entrypoint.sh /entrypoint.sh
COPY scripts/vpn-agent.ps1 ./agent/vpn-agent.ps1
RUN chmod +x /entrypoint.sh

ENV NODE_ENV=production
EXPOSE 8443
EXPOSE 51820/udp

VOLUME ["/etc/wireguard", "/data"]

ENTRYPOINT ["/entrypoint.sh"]
