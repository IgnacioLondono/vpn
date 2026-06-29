# VP´N Makefile
SHELL := /bin/bash
ROOT  := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
SCRIPTS := $(ROOT)scripts
.PHONY: help init validate start stop restart logs build backup health deploy-ssl

help:
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

init: ## Crear .env con JWT aleatorio
	@cp -n .env.example .env 2>/dev/null || true
	@grep -q '^JWT_SECRET=.\+' .env || sed -i "s/^JWT_SECRET=$$/JWT_SECRET=$$(openssl rand -hex 32)/" .env
	@echo "[OK] Edita .env: ADMIN_PASSWORD, WG_HOST"

validate: ## Validar .env
	@bash $(SCRIPTS)/validate-env.sh

build: ## Construir imagen Docker
	@docker compose build

start: validate build ## Iniciar portal VPN
	@mkdir -p data/wireguard data/portal backups
	@docker compose up -d
	@docker compose ps

stop: ## Detener stack
	@docker compose --profile ssl down

restart: ## Reiniciar
	@docker compose restart

logs: ## Logs del portal
	@docker compose logs -f --tail=100 vpn-portal

backup: ## Backup configuración
	@bash $(SCRIPTS)/backup.sh

health: ## Healthcheck
	@bash $(SCRIPTS)/healthcheck.sh

deploy-ssl: validate ## Desplegar con HTTPS (Caddy)
	@docker compose -f docker-compose.yml -f docker-compose.prod.yml -f docker-compose.ssl.yml --profile ssl up -d --build

install: ## Instalación completa Linux
	@sudo bash $(SCRIPTS)/install-server.sh
