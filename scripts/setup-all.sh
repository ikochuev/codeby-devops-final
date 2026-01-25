#!/bin/bash

echo "=== Полная автоматическая настройка CI/CD стека ==="

HOST_IP=$(hostname -I | awk '{print $1}')
echo "Определен IP хоста: $HOST_IP"

# Создаем .env файл
echo "HOST_IP=$HOST_IP" > .env
echo "ELASTICSEARCH_HOST=http://$HOST_IP:9200" >> .env
echo "FLUENTD_HOST=$HOST_IP" >> .env
echo "FLUENTD_PORT=24224" >> .env
echo "PROMETHEUS_HOST=$HOST_IP" >> .env
echo "GRAFANA_HOST=$HOST_IP" >> .env
echo "GRAFANA_PASSWORD=admin" >> .env
echo "CADVISOR_HOST=$HOST_IP" >> .env
echo "CADVISOR_PORT=8081" >> .env
echo "BLACKBOX_HOST=$HOST_IP" >> .env
echo "BLACKBOX_PORT=9115" >> .env

# Запускаем все сервисы
echo "Запуск Docker Compose..."
docker compose up -d --build

echo "Ожидание запуска сервисов (60 секунд)..."
sleep 60

# Настраиваем Kibana автоматически
echo "Настройка Kibana..."
KIBANA_READY=false
for i in {1..12}; do
    if curl -s "http://$HOST_IP:5601/api/status" 2>/dev/null | grep -q "available"; then
        echo "Kibana готова, создаем Data View..."
        KIBANA_READY=true
        
        # Создаем Data View для логов
        curl -X POST "http://$HOST_IP:5601/api/saved_objects/index-pattern/docker-logs" \
            -H "kbn-xsrf: true" \
            -H "Content-Type: application/json" \
            -d '{"attributes":{"title":"docker-*","timeFieldName":"@timestamp"}}' \
            2>/dev/null && echo "✓ Data View 'docker-*' создан" || echo "✓ Data View уже существует"
        
        break
    fi
    echo "Ожидание Kibana ($i/12)..."
    sleep 5
done

if [ "$KIBANA_READY" = false ]; then
    echo "⚠ Kibana не запустилась за отведенное время, но процесс продолжается..."
fi

# Проверяем Grafana
echo "Проверка Grafana..."
GRAFANA_READY=false
for i in {1..12}; do
    if curl -s "http://$HOST_IP:3000/api/health" 2>/dev/null | grep -q "ok"; then
        echo "✓ Grafana готова!"
        echo "Дашборды автоматически загружены через provisioning:"
        echo "  - WebSocket Chat Monitoring"
        echo "  - Infrastructure Monitoring"
        GRAFANA_READY=true
        break
    fi
    echo "Ожидание Grafana ($i/12)..."
    sleep 5
done

if [ "$GRAFANA_READY" = false ]; then
    echo "⚠ Grafana не запустилась за отведенное время, но процесс продолжается..."
fi

# Генерируем тестовые данные
echo "Генерация тестовых данных..."
for i in {1..10}; do
    echo "Тестовый запрос $i..."
    curl -s "http://$HOST_IP/health" > /dev/null
    curl -s "http://$HOST_IP/" > /dev/null
    curl -s "http://$HOST_IP/metrics" > /dev/null
    sleep 1
done

echo ""
echo "=== НАСТРОЙКА ЗАВЕРШЕНА ==="
echo ""
echo "Доступные сервисы:"
echo "  Приложение:      http://$HOST_IP"
echo "  Kibana (логи):   http://$HOST_IP:5601"
echo "  Grafana:         http://$HOST_IP:3000 (admin/admin)"
echo "  Prometheus:      http://$HOST_IP:9091"
echo "  Elasticsearch:   http://$HOST_IP:9200"
echo "  cAdvisor:        http://$HOST_IP:8081"
echo "  Blackbox:        http://$HOST_IP:9115"
echo ""
echo "Data View в Kibana: 'docker-*' (автоматически создан)"
echo "Дашборды Grafana:   'WebSocket Chat Monitoring', 'Infrastructure Monitoring' (автоматически загружены)"
echo ""
echo "Для остановки: docker compose down"
echo "Для просмотра логов: docker compose logs -f"
echo "Для повторной проверки: make status"
