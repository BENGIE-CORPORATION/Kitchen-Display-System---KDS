## ══════════════════════════════════════════════════════════════════════════════
##  KDS — Kitchen Display System · Makefile raíz
## ══════════════════════════════════════════════════════════════════════════════

# ── Detectar docker compose v2 vs v1 ─────────────────────────────────────────
DOCKER_COMPOSE := $(shell \
  if docker compose version > /dev/null 2>&1; then \
    echo "docker compose"; \
  else \
    echo "docker-compose"; \
  fi)

DC      := $(DOCKER_COMPOSE) -f docker-compose.yml
DC_PROD := $(DOCKER_COMPOSE) -f docker-compose.prod.yml

# ── Comando para abrir URLs en el navegador (macOS / Linux) ──────────────────
OPEN := $(shell which xdg-open 2>/dev/null || which open 2>/dev/null || echo "")

.DEFAULT_GOAL := help

.PHONY: up down restart rebuild reload stop start \
        logs logs-backend logs-frontend logs-prometheus logs-grafana \
        ps stats health \
        shell-backend shell-frontend \
        lint format typecheck \
        test test-coverage \
        flutter-analyze flutter-rebuild \
        prod-up prod-down prod-rebuild prod-logs prod-ps \
        clean prune \
        help

## ── Ciclo de vida (desarrollo) ───────────────────────────────────────────────

up: ## Arrancar todos los servicios y abrir en el navegador
	$(DC) up -d
	@echo ""
	@echo "  ┌──────────────────────────────────────────────────┐"
	@echo "  │  Frontend    →  http://localhost:3000            │"
	@echo "  │  Backend     →  http://localhost:8000            │"
	@echo "  │  API Docs    →  http://localhost:8000/docs       │"
	@echo "  │  Metrics     →  http://localhost:8000/metrics    │"
	@echo "  │  Prometheus  →  http://localhost:9090            │"
	@echo "  │  Grafana     →  http://localhost:3001            │"
	@echo "  │               usuario: admin / kds2024           │"
	@echo "  └──────────────────────────────────────────────────┘"
	@echo ""
	@if [ -n "$(OPEN)" ]; then \
	  sleep 2; \
	  $(OPEN) http://localhost:3000 & \
	  $(OPEN) http://localhost:8000/docs & \
	  $(OPEN) http://localhost:3001 & \
	fi

down: ## Detener y eliminar contenedores (los volúmenes se conservan)
	$(DC) down

restart: ## Reiniciar todos los servicios
	$(DC) restart

rebuild: ## Reconstruir imágenes y arrancar
	$(DC) up -d --build

reload: ## Forzar recreación de todos los contenedores
	$(DC) up -d --force-recreate

stop: ## Detener contenedores sin eliminarlos
	$(DC) stop

start: ## Arrancar contenedores detenidos
	$(DC) start

## ── Logs ─────────────────────────────────────────────────────────────────────

logs: ## Seguir logs de todos los servicios
	$(DC) logs -f

logs-backend: ## Seguir logs del backend
	$(DC) logs -f backend

logs-frontend: ## Seguir logs del frontend
	$(DC) logs -f frontend

logs-prometheus: ## Seguir logs de Prometheus
	$(DC) logs -f prometheus

logs-grafana: ## Seguir logs de Grafana
	$(DC) logs -f grafana

## ── Estado ───────────────────────────────────────────────────────────────────

ps: ## Ver estado de los contenedores
	$(DC) ps

stats: ## Uso de recursos en tiempo real
	docker stats $$($(DC) ps -q)

health: ## Consultar el endpoint /health del backend
	@curl -s http://localhost:8000/health | python3 -m json.tool

## ── Shells ───────────────────────────────────────────────────────────────────

shell-backend: ## Shell bash dentro del contenedor backend
	$(DC) exec backend bash

shell-frontend: ## Shell sh dentro del contenedor frontend (nginx)
	$(DC) exec frontend sh

## ── Calidad de código (backend) ──────────────────────────────────────────────

lint: ## Ruff check — analizar el código Python
	$(DC) exec backend ruff check /app/app

format: ## Ruff format — formatear el código Python
	$(DC) exec backend ruff format /app/app

typecheck: ## Mypy — verificar tipos en el código Python
	$(DC) exec backend mypy /app/app

## ── Tests ────────────────────────────────────────────────────────────────────

test: ## Ejecutar pytest dentro del contenedor backend
	$(DC) exec backend python -m pytest /app/../Testing/backend -v

test-coverage: ## Pytest con reporte de cobertura
	$(DC) exec backend python -m pytest /app/../Testing/backend -v \
	    --cov=app --cov-report=term-missing

## ── Flutter (frontend) ───────────────────────────────────────────────────────

flutter-analyze: ## Ejecutar flutter analyze dentro del contenedor frontend
	@echo "Nota: flutter analyze requiere el SDK — ejecutar localmente:"
	@echo "  cd Frontend/kds && flutter analyze"

flutter-rebuild: ## Reconstruir solo la imagen del frontend
	$(DC) build --no-cache frontend
	$(DC) up -d --no-deps frontend

## ── Dependencias ─────────────────────────────────────────────────────────────

add-backend-dep: ## Agregar dependencia Python: make add-backend-dep pkg=<nombre>
	@test -n "$(pkg)" || (echo "Uso: make add-backend-dep pkg=<nombre-paquete>" && exit 1)
	$(DC) exec backend pip install $(pkg)
	@echo ""
	@echo "  Agrega '$(pkg)>=VERSION' manualmente a Backend/Pyproject.toml"
	@echo "  Luego ejecuta: make rebuild"

## ── Producción ───────────────────────────────────────────────────────────────

prod-up: ## Arrancar stack de producción (con Caddy + SSL)
	$(DC_PROD) up -d
	@echo ""
	@echo "  ┌──────────────────────────────────────────────────────────────┐"
	@echo "  │  Frontend    →  https://$$DOMAIN                             │"
	@echo "  │  Backend     →  https://$$API_DOMAIN                         │"
	@echo "  │  API Docs    →  desactivado en producción                    │"
	@echo "  │  Grafana     →  ssh -L 3001:localhost:3000 user@servidor     │"
	@echo "  └──────────────────────────────────────────────────────────────┘"
	@echo ""

prod-down: ## Detener stack de producción
	$(DC_PROD) down

prod-rebuild: ## Reconstruir y arrancar stack de producción
	$(DC_PROD) up -d --build

prod-logs: ## Seguir logs de producción
	$(DC_PROD) logs -f

prod-logs-caddy: ## Seguir logs de Caddy (SSL, requests)
	$(DC_PROD) logs -f caddy

prod-ps: ## Estado de los contenedores de producción
	$(DC_PROD) ps

prod-health: ## Health check en producción
	@curl -sf https://$${API_DOMAIN:-localhost:8000}/health | python3 -m json.tool || \
	 curl -sf http://localhost:8000/health | python3 -m json.tool

prod-shell-backend: ## Shell bash en el contenedor backend de producción
	$(DC_PROD) exec backend bash

prod-reload-caddy: ## Recargar configuración de Caddy sin downtime
	$(DC_PROD) exec caddy caddy reload --config /etc/caddy/Caddyfile

prod-grafana-tunnel: ## Abrir tunnel SSH a Grafana de producción: make prod-grafana-tunnel HOST=user@servidor
	@test -n "$(HOST)" || (echo "Uso: make prod-grafana-tunnel HOST=user@servidor" && exit 1)
	@echo "Grafana disponible en http://localhost:3001 — Ctrl+C para cerrar"
	ssh -N -L 3001:localhost:3000 $(HOST)

## ── Limpieza ─────────────────────────────────────────────────────────────────

clean: ## Eliminar contenedores, redes y volúmenes de desarrollo
	@echo ""
	@echo "  ╔═══════════════════════════════════════════════╗"
	@echo "  ║  ADVERTENCIA: se eliminarán todos los datos  ║"
	@echo "  ╚═══════════════════════════════════════════════╝"
	@echo ""
	@read -p "  Escribe YES para continuar: " confirm && [ "$$confirm" = "YES" ] || (echo "Cancelado." && exit 1)
	$(DC) down -v --remove-orphans

prune: ## docker system prune — liberar espacio en disco
	docker system prune -f

## ── Ayuda ────────────────────────────────────────────────────────────────────

help: ## Mostrar todos los targets disponibles
	@echo ""
	@echo "  KDS — Kitchen Display System"
	@echo "  Targets disponibles:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; section=""} \
		/^## ── / { gsub(/^## ── | ─+$$/, "", $$0); section=$$0; printf "\n  \033[1;34m%s\033[0m\n", section } \
		/^[a-zA-Z_-]+:.*##/ { printf "    \033[36m%-26s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)
	@echo ""
