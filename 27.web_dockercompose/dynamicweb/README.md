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
├── test.sh                     # Автоматические тесты (12 проверок)
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

## Требования

- Linux-хост (Ubuntu 20.04/22.04/24.04 или аналог)
- Docker 20.10+
- docker-compose 1.29+

### Установка Docker (если не установлен)

```bash
sudo apt update
sudo apt install -y apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
sudo apt update
sudo apt install -y docker-ce docker-compose
```

Добавить текущего пользователя в группу docker (чтобы не писать `sudo`):

```bash
sudo usermod -aG docker $USER
newgrp docker
```

## Запуск

```bash
cd dynamicweb
docker-compose up -d
```

Первый запуск займёт несколько минут — скачиваются образы и собирается контейнер Django.

Проверить статус контейнеров:

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

## Проверка работоспособности

### Автоматические тесты

```bash
bash test.sh
```

Скрипт выполняет 12 проверок: статус контейнеров, HTTP-коды, содержимое ответов.

Ожидаемый результат:

```
========================================================
  Тестирование стенда: Dynamic Web Deploy
========================================================

[1/4] Проверка статуса контейнеров
-----------------------------------------------------------
  Контейнер 'nginx' запущен                          [PASS]
  Контейнер 'wordpress' запущен                      [PASS]
  Контейнер 'database' запущен                       [PASS]
  Контейнер 'app' запущен                            [PASS]
  Контейнер 'node' запущен                           [PASS]

[2/4] WordPress (PHP-FPM) — порт 8083
-----------------------------------------------------------
  HTTP-ответ от WordPress (200 или 302)              [PASS] HTTP 302
  WordPress install page                             [PASS] HTTP 200
  Install page содержит 'WordPress'                  [PASS]

[3/4] Django (Gunicorn) — порт 8081
-----------------------------------------------------------
  HTTP-ответ от Django                               [PASS] HTTP 200
  Django отвечает корректно                          [PASS]

[4/4] Node.js — порт 8082
-----------------------------------------------------------
  HTTP-ответ от Node.js                              [PASS] HTTP 200
  Node.js отвечает 'Hello'                           [PASS]

========================================================
  Итого тестов: 12
  Успешно:      12
  Провалено:    0
========================================================

  ✓ ВСЕ ТЕСТЫ ПРОЙДЕНЫ УСПЕШНО
```

### Ручная проверка через curl

```bash
# Node.js — порт 8082 (самый простой, текстовый ответ)
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

### Проверка в браузере

Если порты доступны извне (или через SSH-туннель):

- `http://<IP>:8081` — Django (страница приветствия)
- `http://<IP>:8082` — Node.js (текст «Hello from node js server»)
- `http://<IP>:8083` — WordPress (мастер установки)

## Описание конфигураций

### docker-compose.yml

5 сервисов в bridge-сети `app-network`:

- **database** — MySQL 8.0, данные в volume `./dbdata`
- **wordpress** — PHP-FPM, подключается к database:3306, файлы в `./wordpress`
- **app** — собирается из `./python/Dockerfile`, gunicorn на порту 8000
- **node** — Node.js 16 Alpine, запускает `test.js` на порту 3000
- **nginx** — `nginx:stable-alpine`, проксирует все три приложения, порты 8081/8082/8083

### nginx.conf

Три server-блока (только IPv4, без `listen [::]:` для совместимости с хостами где отключён IPv6):

- `:8083` → `fastcgi_pass wordpress:9000` (PHP-FPM протокол)
- `:8081` → `proxy_pass http://app:8000` (HTTP, через upstream `django`)
- `:8082` → `proxy_pass http://node:3000` (HTTP)

### .env

```
DB_NAME=wordpress              # имя БД MySQL
DB_ROOT_PASSWORD=dbpassword    # пароль root MySQL
MYSITE_SECRET_KEY=...          # секретный ключ Django
DEBUG=True                     # режим отладки Django
```

## Диагностика при проблемах

```bash
# Логи контейнера
docker logs nginx
docker logs app
docker logs node
docker logs wordpress
docker logs database

# Перезапуск всего стенда
docker-compose down
docker-compose up -d

# Пересборка Django-контейнера после изменений кода
docker-compose up -d --build app

# Полная очистка (удалить всё, включая данные БД)
docker-compose down -v
rm -rf dbdata wordpress
```

## Решённые проблемы при развёртывании

| Проблема | Причина | Решение |
|----------|---------|---------|
| `PermissionError: Permission denied` при `docker-compose ps` | Пользователь не в группе `docker` | `sudo usermod -aG docker $USER && newgrp docker` |
| nginx в статусе `Restarting` | IPv6 отключён на хосте, а в конфиге `listen [::]:` | Убраны директивы `listen [::]:` из `nginx.conf` |
| WordPress отдаёт 302 вместо 200 | Штатное поведение — редирект на `/wp-admin/install.php` до установки | Тест скорректирован: ожидает 302 для `/`, проверяет контент на install-странице |

## Остановка

```bash
# Остановить контейнеры (данные сохраняются)
docker-compose down

# Остановить и удалить все данные
docker-compose down -v
rm -rf dbdata wordpress
```

## Источники

- [Docker Compose — Getting Started](https://docs.docker.com/compose/gettingstarted/)
- [Nginx Documentation](https://nginx.org/ru/docs/)
- [Docker Hub](https://hub.docker.com/)
