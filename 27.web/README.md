# Развертывание веб-приложения (Dynamic Web Deploy)

## Описание

Стенд из трёх веб-приложений разных технологий, работающих за единым nginx-прокси. Развёрнуто через **docker-compose** на одной Linux-машине.

| Порт | Технология | Приложение | Проксирование |
|------|-----------|------------|---------------|
| 8081 | Python (Django + Gunicorn) | Стандартный Django-проект | `proxy_pass` → `app:8000` |
| 8082 | JavaScript (Node.js) | HTTP-сервер на модуле `http` | `proxy_pass` → `node:3000` |
| 8083 | PHP-FPM (WordPress) | WordPress 5.1 + MySQL 8.0 | `fastcgi_pass` → `wordpress:9000` |

## Архитектура

```
                  ┌─────────────────────────────────┐
                  │           NGINX                  │
                  │  :8081  :8082  :8083             │
                  └──┬────────┬────────┬────────────┘
                     │        │        │
           ┌─────────┘   ┌────┘   ┌────┘
           ▼             ▼        ▼
     ┌───────────┐ ┌──────────┐ ┌────────────┐
     │  Django   │ │  Node.js │ │  WordPress  │
     │ Gunicorn  │ │  :3000   │ │  PHP-FPM    │
     │  :8000    │ │          │ │  :9000      │
     └───────────┘ └──────────┘ └──────┬─────┘
                                       │
                                 ┌─────▼─────┐
                                 │  MySQL 8.0 │
                                 └────────────┘
```

5 контейнеров в единой Docker-сети `app-network`. Nginx — единая точка входа.

## Структура проекта

```
dynamicweb/
├── docker-compose.yml          # Описание всех 5 сервисов
├── .env                        # Переменные окружения (БД, Django)
├── README.md
├── nginx-conf/
│   └── nginx.conf              # 3 server-блока (WordPress, Django, Node)
├── node/
│   └── test.js                 # Node.js приложение
└── python/
    ├── Dockerfile              # Сборка образа Django + Gunicorn
    ├── manage.py
    ├── requirements.txt        # Django 3.1, Gunicorn, pytz
    └── mysite/
        ├── __init__.py
        ├── asgi.py
        ├── settings.py
        ├── urls.py
        └── wsgi.py
```


- Linux-хост Ubuntu 24.04
- Docker 20.10+
- docker-compose 1.29+

### Ставим Docker

```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-compose
```

Добавляем текущего пользователя в группу docker (чтобы не писать `sudo`):

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Запуск

```bash
cd dynamicweb
docker-compose up -d
```

Первый запуск займёт пару минут — скачиваются образы и собирается контейнер Django.

Проверяем статус контейнеров:

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

Ожидаемый вывод — 5 контейнеров `Up`:

```
NAMES       STATUS          PORTS
nginx       Up 2 minutes    0.0.0.0:8081-8083->8081-8083/tcp
wordpress   Up 2 minutes    9000/tcp
database    Up 2 minutes    3306/tcp, 33060/tcp
app         Up 2 minutes
node        Up 2 minutes
```

### Проверяем через curl

```bash
# Node.js — порт 8082 
curl http://localhost:8082/
# Ожидаем: Hello from node js server

# Django — порт 8081
curl http://localhost:8081/
# Ожидаем: HTML-страница "The install worked successfully"

# WordPress — порт 8083 (редирект 302 на установку, -L следует за ним)
curl -L http://localhost:8083/
# Ожидаем: HTML-страница установки WordPress

# Коды ответов всех трёх одной командой:
for port in 8081 8082 8083; do
  echo "Порт $port: $(curl -s -o /dev/null -w '%{http_code}' http://localhost:$port/)"
done
```
