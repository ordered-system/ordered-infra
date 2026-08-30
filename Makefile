.PHONY: help up down logs restart topics ps

help: ## Show this help message
	@echo Available commands:
	@echo   up       - Start Kafka + Kafka UI + Prometheus + Grafana + Jaeger
	@echo   down     - Stop and remove containers (keeps data volumes)
	@echo   logs     - Tail logs from the Kafka broker
	@echo   restart  - Restart the broker
	@echo   topics   - List topics currently on the broker
	@echo   ps       - Show container status

up: ## Start Kafka + Kafka UI + Prometheus + Grafana + Jaeger
	docker compose up -d
	@echo Kafka:      localhost:29092
	@echo Kafka UI:   http://localhost:8090
	@echo Prometheus: http://localhost:9090
	@echo Grafana:    http://localhost:3000 (admin/admin, or anonymous viewer access)
	@echo Jaeger UI:  http://localhost:16686

down: ## Stop and remove containers (keeps data volumes)
	docker compose down

logs: ## Tail logs from the Kafka broker
	docker compose logs -f kafka

restart: ## Restart the broker
	docker compose restart kafka

topics: ## List topics currently on the broker
	docker exec ordered-kafka /opt/kafka/bin/kafka-topics.sh --bootstrap-server localhost:9092 --list

ps: ## Show container status
	docker compose ps
