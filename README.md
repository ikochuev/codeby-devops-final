
###Полный CI/CD пайплайн со стеком мониторинга
##🚀 codeby-devops-final


##📖 О проекте
Готовый к развёртыванию проект, демонстрирующий полный цикл CI/CD с использованием GitHub Actions для приложения на Go. Включает в себя:
Веб-приложение: WebSocket чат на Go с метриками Prometheus.
Полный стек мониторинга: Prometheus, Grafana, cAdvisor, Blackbox Exporter.
Стек логирования (EFK): Fluentd, Elasticsearch, Kibana.
Автоматизированный пайплайн: Автоматические тесты, сборка Docker-образов, публикация в реестры и развёртывание.
Версионирование и релизы: Автоматическое создание релизов с бинарными файлами для разных ОС.

##🌐 Архитектура
Пользователь -> [Nginx:80] -> [Go-приложение:8080]
                            -> [Grafana:3000] -> [Prometheus:9090]
                            -> [Kibana:5601]  -> [Elasticsearch:9200]

Все сервисы логируются через Fluentd в Elasticsearch. cAdvisor и Blackbox Exporter собирают метрики инфраструктуры и доступности.

##⚙️ Быстрый старт (локальное развёртывание)
# 1. Клонировать репозиторий
git clone https://github.com/<ваш-username>/codeby-devops-final.git
cd codeby-devops-final

# 2. Запустить полную автоматическую настройку (Docker & Docker Compose обязательны)
make auto-setup
Через 1-2 минуты все сервисы будут доступны по адресам ниже.

##🔗 Доступ к сервисам
Сервис	                Назначение	                    URL (замените <YOUR_IP>)	Данные для входа
Основное приложение	    WebSocket чат	                http://<YOUR_IP>	        –
Grafana	                Дашборды и визуализация метрик	http://<YOUR_IP>:3000	    admin / admin
Prometheus	            Сбор и запрос метрик	        http://<YOUR_IP>:9091	    –
Kibana	                Анализ и просмотр логов	        http://<YOUR_IP>:5601	    –
Elasticsearch	        Хранилище и API логов	        http://<YOUR_IP>:9200	    –
cAdvisor	            Метрики контейнеров	            http://<YOUR_IP>:8081	    –

##🛠 Управление развёртыванием (Makefile)

make auto-setup   # Полная автоматическая настройка (рекомендуется)
make up           # Запустить все сервисы
make down         # Остановить все сервисы
make logs         # Просмотр логов в реальном времени
make status       # Проверка состояния контейнеров
make health       # Проверка здоровья ключевых сервисов
make urls         # Показать все доступные URL
make clean        # Полная очистка (контейнеры, тома, образы)

##🔄 CI/CD Pipeline (GitHub Actions)
Проект включает два автоматических workflow:

1. Основной CI/CD пайплайн (.github/workflows/ci-cd.yml)
Запуск: При пуше в ветки main/master и создании Pull Request.
Этапы:

Test: Запуск unit-тестов Go приложения с генерацией отчёта о покрытии (Codecov).
Build and Push: Сборка Docker-образов и публикация в Docker Hub (<username>/codeby-devops-final) и GitHub Container Registry (GHCR).
Deploy (только для main): Автоматическое развёртывание на целевую инфраструктуру.
Monitoring: Финальная проверка работоспособности развёрнутых сервисов.

2. Release Pipeline (.github/workflows/release.yml)
Запуск: При создании git-тега, начинающегося с v* (например, v1.0.0).
Действие: Собирает бинарные файлы приложения для Linux, macOS и Windows и создаёт готовый релиз на GitHub с прикреплёнными артефактами.

##🔐 Настройка секретов для CI/CD
Для публикации образов в Docker Hub добавьте в настройках репозитория GitHub (Settings → Secrets and variables → Actions):
DOCKER_USERNAME — ваш логин на Docker Hub.
DOCKERHUB_TOKEN — Access Token (с правами Read, Write, Delete), созданный в настройках аккаунта Docker Hub.
Публикация в GitHub Container Registry (GHCR) работает автоматически с использованием встроенного GITHUB_TOKEN.

##📁 Структура проекта
codeby-devops-final/
├── .github/workflows/     # CI/CD пайплайны GitHub Actions
├── app/                   # Исходный код Go-приложения (WebSocket чат)
├── fluentd/               # Конфигурация Fluentd для сбора логов
├── grafana/               # Provisioning Grafana (дашборды, источники данных)
├── prometheus/            # Конфигурация Prometheus
├── blackbox/              # Конфигурация Blackbox Exporter
├── nginx/                 # Конфигурация Nginx как reverse proxy
├── scripts/               # Скрипты автоматизации
├── docker-compose.yml     # Основной файл развёртывания всех сервисов
├── Makefile               # Управление проектом через make-команды
└── README.md              # Эта документация