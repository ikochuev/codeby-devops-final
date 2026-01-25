.PHONY: all up down logs status health urls auto-setup clean monitoring logs-app logs-mon logs-efk check-efk setup-kibana show-ip check-network indices

HOST_IP := $(shell hostname -I | awk '{print $$1}')

all: auto-setup

auto-setup:
	@echo "🚀 Автоматическая настройка всего стека..."
	@./scripts/setup-all.sh

up:
	@echo "Запуск сервисов..."
	@HOST_IP=$(HOST_IP) docker compose up -d --build
	@sleep 10
	@make status

down:
	@echo "Остановка сервисов..."
	docker compose down

logs:
	docker compose logs -f

logs-app:
	docker compose logs -f go-chat-app

logs-mon:
	docker compose logs -f prometheus grafana

logs-efk:
	docker compose logs -f elasticsearch kibana fluentd

status:
	@echo "=== Статус сервисов ==="
	docker compose ps --format "table {{.Name}}\t{{.Status}}\t{{.Ports}}"

health:
	@echo "=== Проверка здоровья ==="
	@echo -n "Приложение: "
	@curl -s http://$(HOST_IP)/health 2>/dev/null | jq -r '.status' || echo "unavailable"
	@echo -n "Elasticsearch: "
	@curl -s http://$(HOST_IP):9200 2>/dev/null | jq -r '.version.number' || echo "unavailable"
	@echo -n "Kibana: "
	@curl -s -o /dev/null -w "%{http_code}" http://$(HOST_IP):5601 2>/dev/null || echo "unavailable"
	@echo -n "Grafana: "
	@curl -s -o /dev/null -w "%{http_code}" http://$(HOST_IP):3000 2>/dev/null || echo "unavailable"

urls:
	@echo "=== Доступные URL ==="
	@echo "Приложение:      http://$(HOST_IP)"
	@echo "Kibana:          http://$(HOST_IP):5601"
	@echo "Grafana:         http://$(HOST_IP):3000 (admin/admin)"
	@echo "Prometheus:      http://$(HOST_IP):9091"
	@echo "Elasticsearch:   http://$(HOST_IP):9200"
	@echo "cAdvisor:        http://$(HOST_IP):8081"
	@echo "Blackbox:        http://$(HOST_IP):9115"

monitoring:
	@echo "Запуск мониторинга..."
	docker compose up -d prometheus grafana cadvisor blackbox-exporter

clean:
	docker compose down -v
	docker system prune -f

check-efk:
	@echo "=== Проверка EFK стека ==="
	@echo "Elasticsearch индексы:"
	@curl -s "http://$(HOST_IP):9200/_cat/indices?v" 2>/dev/null || echo "Elasticsearch недоступен"
	@echo ""
	@echo "Тест логов..."
	@for i in 1 2 3; do curl -s http://$(HOST_IP)/health > /dev/null && echo "✓ Запрос $$i отправлен"; sleep 1; done
	@sleep 5
	@echo ""
	@echo "Проверка новых индексов..."
	@curl -s "http://$(HOST_IP):9200/_cat/indices?v" 2>/dev/null | grep -E "docker|fluentd" || echo "Индексы не найдены"

setup-kibana:
	@echo "=== Настройка Kibana ==="
	@echo "Ожидание Kibana..."
	@for i in {1..12}; do \
		if curl -s http://$(HOST_IP):5601/api/status 2>/dev/null | grep -q "available"; then \
			echo "Kibana готова!"; \
			break; \
		fi; \
		echo "Попытка $$i/12..."; \
		sleep 5; \
	done
	@echo "Создание Data View..."
	@curl -X POST "http://$(HOST_IP):5601/api/saved_objects/index-pattern/docker-logs" \
		-H "kbn-xsrf: true" \
		-H "Content-Type: application/json" \
		-d '{"attributes":{"title":"docker-*","timeFieldName":"@timestamp"}}' 2>/dev/null && echo "✓ Создан docker-*" || echo "⚠ Уже существует"
	@echo ""
	@echo "Kibana доступна: http://$(HOST_IP):5601"

show-ip:
	@echo "HOST_IP: $(HOST_IP)"

check-network:
	@echo "=== Диагностика сети ==="
	@echo "Docker сети:"
	@docker network ls 2>/dev/null || true
	@echo ""
	@echo "IP контейнеров:"
	@docker ps -q 2>/dev/null | xargs -I {} docker inspect -f '{{.Name}} - {{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' {} 2>/dev/null | grep -v "^$$" || true

indices:
	@echo "=== Elasticsearch индексы ==="
	@curl -s "http://$(HOST_IP):9200/_cat/indices?v" 2>/dev/null || echo "Elasticsearch недоступен"
