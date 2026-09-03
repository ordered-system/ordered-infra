.PHONY: help up down logs restart topics ps prod-up prod-down prod-logs prod-ps prod-build

help: ## Show this help message
	@echo Available commands:
	@echo   up          - Start local dev infra: Kafka + Kafka UI + Prometheus + Grafana + Jaeger
	@echo   down        - Stop and remove local dev containers (keeps data volumes)
	@echo   logs        - Tail logs from the local dev Kafka broker
	@echo   restart     - Restart the local dev broker
	@echo   topics      - List topics on the local dev broker
	@echo   ps          - Show local dev container status
	@echo   prod-up     - Start the FULL production stack (see docs/DEPLOY.md first)
	@echo   prod-down   - Stop the production stack (keeps data volumes)
	@echo   prod-logs   - Tail logs from every production container
	@echo   prod-ps     - Show production container status
	@echo   prod-build  - Rebuild and restart one production service, e.g. make prod-build SERVICE=order-service

up: ## Start local dev infra: Kafka + Kafka UI + Prometheus + Grafana + Jaeger
	docker compose up -d
	@echo Kafka:      localhost:29092
	@echo Kafka UI:   http://localhost:8090
	@echo Prometheus: http://localhost:9090
	@echo Grafana:    http://localhost:3000 (admin/admin, or anonymous viewer access)
	@echo Jaeger UI:  http://localhost:16686

down: ## Stop and remove local dev containers (keeps data volumes)
	docker compose down

logs: ## Tail logs from the local dev Kafka broker
	docker compose logs -f kafka

restart: ## Restart the local dev broker
	docker compose restart kafka

topics: ## List topics on the local dev broker
	docker exec ordered-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

ps: ## Show local dev container status
	docker compose ps

prod-up: ## Start the FULL production stack (see docs/DEPLOY.md first)
	docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build

prod-down: ## Stop the production stack (keeps data volumes)
	docker compose -f docker-compose.prod.yml --env-file .env.prod down

prod-logs: ## Tail logs from every production container
	docker compose -f docker-compose.prod.yml logs -f

prod-ps: ## Show production container status
	docker compose -f docker-compose.prod.yml --env-file .env.prod ps

prod-build: ## Rebuild and restart one production service, e.g. make prod-build SERVICE=order-service
	docker compose -f docker-compose.prod.yml --env-file .env.prod up -d --build $(SERVICE)