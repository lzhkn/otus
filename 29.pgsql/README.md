# PostgreSQL 16 — Hot Standby репликация + резервное копирование (Barman)

## Описание задания

1. Настраиваем **hot_standby репликацию** PostgreSQL с использованием слотов
2. Настраиваем **резервное копирование** с помощью Barman

**Стенд:** 3 ВМ на Proxmox VE, Ubuntu 24.04, PostgreSQL 16

---

## Архитектура

| Роль                           | Hostname    | IP            | CPU | RAM  | Диск  |
|--------------------------------|-------------|---------------|-----|------|-------|
| Master PostgreSQL              | `pgsql-01`  | 192.168.0.155 | 4   | 4 ГБ | 32 ГБ |
| Slave PostgreSQL (hot_standby) | `pgsql-02`  | 192.168.0.156 | 4   | 4 ГБ | 32 ГБ |
| Barman (бэкапы)                | `barman-01` | 192.168.0.157 | 4   | 4 ГБ | 32 ГБ |

---

## Подготовка ВМ

###  На ВСЕХ трёх ВМ — базовая подготовка

```bash
# Переходим в root
sudo -i

# Обновляем систему
apt update && apt upgrade -y

# Ставим базовые утилиты
apt install -y vim telnet wget curl gnupg2 lsb-release

# Прописываем hostnames (на каждой ВМ свой)
hostnamectl set-hostname pgsql-01   # на первой
hostnamectl set-hostname pgsql-02   # на второй
hostnamectl set-hostname barman-01  # на третьей
```

### На ВСЕХ трёх ВМ — прописываем /etc/hosts

```bash
nano /etc/hosts
192.168.0.155 pgsql-01
192.168.0.156 pgsql-02
192.168.0.157 barman-01

```

### Проверяем связность

```bash
# С каждой ВМ пингуем остальные
ping -c 2 pgsql-01
ping -c 2 pgsql-02
ping -c 2 barman-01
```

---

## Установливаем PostgreSQL 16 на pgsql-01 и pgsql-02 

> Выполняем на **pgsql-01** и **pgsql-02**

```bash
# Установка PostgreSQL 16 (из стандартного репозитория Ubuntu 24.04)
apt install -y postgresql postgresql-contrib

# Проверяем статус
systemctl status postgresql

# Убеждаемся что версия 16
sudo -u postgres psql -c "SELECT version();"

# Включаем автозапуск
systemctl enable postgresql
```

**Важно:** В Ubuntu 24.04 PostgreSQL 16 ставится из коробки. Конфиги лежат в `/etc/postgresql/16/main/`, данные — в `/var/lib/postgresql/16/main/`.

---

## Настройка Master (pgsql-01) 

### Создаём пользователя для репликации

```bash
sudo -u postgres psql
```

```sql
CREATE USER replicator WITH REPLICATION ENCRYPTED PASSWORD 'Otus2022!';
-- Проверяем
\du
-- Выходим
\q
```

### Редактируем postgresql.conf

```bash
vim /etc/postgresql/16/main/postgresql.conf
```

Находим и меняем/добавляем следующие параметры:

```ini
# Сетевые настройки
listen_addresses = 'localhost, 192.168.0.155'
port = 5432
max_connections = 100

# Логирование
log_directory = 'log'
log_filename = 'postgresql-%a.log'
log_rotation_age = 1d
log_rotation_size = 0
log_truncate_on_rotation = on
log_line_prefix = '%m [%p] '
log_timezone = 'UTC+3'

# Локализация
timezone = 'UTC+3'
datestyle = 'iso, mdy'
lc_messages = 'en_US.UTF-8'
lc_monetary = 'en_US.UTF-8'
lc_numeric = 'en_US.UTF-8'
lc_time = 'en_US.UTF-8'
default_text_search_config = 'pg_catalog.english'

# === РЕПЛИКАЦИЯ ===
# Уровень WAL для репликации
wal_level = replica
# Максимальное количество WAL-отправителей (слейвов + бэкап)
max_wal_senders = 3
# Максимальное количество слотов репликации
max_replication_slots = 3
# Размер WAL
max_wal_size = 1GB
min_wal_size = 80MB
# Разрешаем запросы на standby
hot_standby = on
# Slave сообщает мастеру о выполняемых запросах
hot_standby_feedback = on
# Шифрование паролей
password_encryption = scram-sha-256
```

### Редактируем pg_hba.conf

```bash
nano /etc/postgresql/16/main/pg_hba.conf
```

Приводим файл к следующему виду:

```
# TYPE  DATABASE        USER            ADDRESS                 METHOD
# Локальные подключения
local   all             all                                     peer
host    all             all             127.0.0.1/32            scram-sha-256
host    all             all             ::1/128                 scram-sha-256

# Репликация — локальные
local   replication     all                                     peer
host    replication     all             127.0.0.1/32            scram-sha-256
host    replication     all             ::1/128                 scram-sha-256

# Репликация — pgsql-01 и pgsql-02
host    replication     replicator      192.168.0.155/32         scram-sha-256
host    replication     replicator      192.168.0.156/32         scram-sha-256
```

### Перезапускаем PostgreSQL

```bash
systemctl restart postgresql
systemctl status postgresql
```

---

##  Настраевае Slave (pgsql-02)

### Останавливаем PostgreSQL на pgsql-02

```bash
systemctl stop postgresql
```

### Удаляем данные по умолчанию

```bash
rm -rf /var/lib/postgresql/16/main/*
```

### Копируем данные с master через pg_basebackup

```bash
sudo -u postgres pg_basebackup \
  -h 192.168.0.155 \
  -U replicator \
  -D /var/lib/postgresql/16/main/ \
  -R -P
```

- Флаг `-R` автоматически создаёт файл `standby.signal` и прописывает параметры подключения в `postgresql.auto.conf`
- Флаг `-P` показывает прогресс
- Будет запрошен пароль: `Otus2022!`

### Меняем listen_addresses на pgsql-02

```bash
nano /etc/postgresql/16/main/postgresql.conf
```

```ini
listen_addresses = 'localhost, 192.168.0.156'
```

### Запускаем PostgreSQL на pgsql-02

```bash
systemctl start postgresql
systemctl status postgresql
```

---

## Проверяем реплику

### Создаём тестовую БД на master (pgsql-01)

```bash
sudo -u postgres psql
```

```sql
CREATE DATABASE otus_test;
\l
```

Ожидаемый результат — в списке появится `otus_test`.

### Проверяем на slave (pgsql-02)

```bash
sudo -u postgres psql
```

```sql
\l
```

**БД `otus_test` должна появиться в списке на pgsql-02!**

### Проверяем статус репликации

**На pgsql-01 (master):**

```sql
SELECT pid, usename, client_addr, state, sync_state
FROM pg_stat_replication;
```

Должна быть строка с `client_addr = 192.168.0.156` и `state = streaming`.

**На pgsql-02 (slave):**

```sql
SELECT status, received_tli, flushed_lsn, latest_end_lsn
FROM pg_stat_wal_receiver;
```

Вывод должен быть не пустым, `status = streaming`.

### Проверяем что slave — read-only

```bash
# На pgsql-02
sudo -u postgres psql
```

```sql
CREATE DATABASE test_write;
```

Ожидаем ошибку: `ERROR: cannot execute CREATE DATABASE in a read-only transaction` — это подтверждает, что pgsql-02 работает в режиме hot_standby.

---

## Настраиваем Barman — резервное копирование 

### Установка пакетов

**На pgsql-01 и pgsql-02:**

```bash
apt install -y barman-cli
```

**На barman-01:**

```bash
apt install -y barman barman-cli postgresql-client
```

### Генерируем SSH-ключи и Настраиваем обмен

**На pgsql-01** (от пользователя postgres):

```bash
su - postgres
ssh-keygen -t rsa -b 4096 -N ""
cat ~/.ssh/id_rsa.pub
```

**На barman-01** (от пользователя barman):

```bash
su - barman
mkdir -p ~/.ssh && chmod 700 ~/.ssh
ssh-keygen -t rsa -b 4096 -N ""

# Вставляем публичный ключ postgres@pgsql-01
nano ~/.ssh/authorized_keys
# Вставить скопированный ключ, сохранить
chmod 600 ~/.ssh/authorized_keys

# Теперь копируем ключ barman на pgsql-01
cat ~/.ssh/id_rsa.pub
```

**На pgsql-01** (от пользователя postgres):

```bash
su - postgres
mkdir -p ~/.ssh && chmod 700 ~/.ssh
nano ~/.ssh/authorized_keys
# Вставить публичный ключ barman, сохранить
chmod 600 ~/.ssh/authorized_keys
```

### Проверяем SSH-доступ

**С barman-01:**

```bash
su - barman
ssh postgres@pgsql-01 "hostname"
# Должно вывести: pgsql-01
```

**С pgsql-01:**

```bash
su - postgres
ssh barman@barman-01 "hostname"
# Должно вывести: barman-01
```

### Создаём пользователя barman в PostgreSQL (на pgsql-01)

```bash
sudo -u postgres psql
```

```sql
CREATE USER barman WITH REPLICATION ENCRYPTED PASSWORD 'Otus2022!';
\q
```


### Обновляем pg_hba.conf на pgsql-01

```bash
nano /etc/postgresql/16/main/pg_hba.conf
```

Добавляем в конец две строки для barman:

```
host    all             barman          192.168.0.157/32         scram-sha-256
host    replication     barman          192.168.0.157/32         scram-sha-256
```

Перезапускаем:

```bash
systemctl restart postgresql
```

### Создаём тестовую БД и таблицу на pgsql-01

```bash
sudo -u postgres psql
```

```sql
CREATE DATABASE otus;
\c otus
CREATE TABLE test (id int, name varchar(30));
INSERT INTO test VALUES (1, 'alex');
INSERT INTO test VALUES (2, 'ivan');
SELECT * FROM test;
\q
```

### Настраиваем .pgpass на barman-01

```bash
su - barman
cat > ~/.pgpass
192.168.0.155:5432:*:barman:Otus2022!

chmod 600 ~/.pgpass
```

### Проверяем подключение barman-01 → pgsql-01

```bash
# От пользователя barman
psql -h 192.168.0.155 -U barman -d postgres -c "SELECT version();"
```

Должна вернуться версия PostgreSQL без запроса пароля.

```bash
psql -h 192.168.0.155 -U barman -c "IDENTIFY_SYSTEM" replication=1
```

Должна вернуться таблица с systemid, timeline, xlogpos.

### Создаём конфигурацию Barman

**Основной конфиг `/etc/barman.conf`:**

```bash
# От root на хосте barman
cat > /etc/barman.conf <<''
[barman]
barman_home = /var/lib/barman
configuration_files_directory = /etc/barman.d
barman_user = barman
log_file = /var/log/barman/barman.log
compression = gzip
backup_method = rsync
archiver = on
retention_policy = REDUNDANCY 3
immediate_checkpoint = true
last_backup_maximum_age = 4 DAYS
minimum_redundancy = 1


chown barman:barman /etc/barman.conf
```

**Конфиг для pgsql-01 — `/etc/barman.d/pgsql-01.conf`:**

```bash
mkdir -p /etc/barman.d

cat > /etc/barman.d/pgsql-01.conf <<''
[pgsql-01]
description = "backup pgsql-01"
ssh_command = ssh postgres@pgsql-01
conninfo = host=192.168.0.155 user=barman port=5432 dbname=postgres
retention_policy_mode = auto
retention_policy = RECOVERY WINDOW OF 7 days
wal_retention_policy = main
streaming_archiver = on
create_slot = auto
slot_name = pgsql_01
streaming_conninfo = host=192.168.0.155 user=barman port=5432
backup_method = postgres
archiver = off


chown barman:barman /etc/barman.d/pgsql-01.conf
```

### Запускаем и проверяем Barman

```bash
su - barman

# Переключаем WAL
barman switch-wal pgsql-01

# Запускаем cron (инициализация получения WAL)
barman cron

# Ждём 5-10 секунд, затем проверяем
barman check pgsql-01
```

**Ожидаемый вывод** — все пункты OK, кроме двух (это нормально до первого бэкапа):

```
backup maximum age: FAILED (no backups)
minimum redundancy requirements: FAILED (have 0 backups, expected at least 1)
```

### Создаём первый бэкап

```bash
barman backup pgsql-01
```

После успешного завершения:

```bash
barman list-backup pgsql-01
```

Должен отобразиться бэкап с датой и размером.

---

## Проверяем восстановление из бэкапа

### Удаляем базы на pgsql-01

```bash
sudo -u postgres psql
```

```sql
\l
DROP DATABASE otus;
DROP DATABASE otus_test;
\l
\q
```

### Восстанавливаем из бэкапа (с barman-01)

```bash
su - barman

# Смотрим ID бэкапа
barman list-backup pgsql-01

# Останавливаем PostgreSQL на pgsql-01 (через SSH)
ssh postgres@pgsql-01 "sudo systemctl stop postgresql"

# Восстанавливаем (подставьте свой ID бэкапа)
barman recover pgsql-01 <BACKUP_ID> /var/lib/postgresql/16/main/ \
  --remote-ssh-command "ssh postgres@pgsql-01"
```

### Перезапускаем PostgreSQL на pgsql-01

```bash
# На pgsql-01
systemctl start postgresql
sudo -u postgres psql -c "\l"
```

**Базы `otus` и `otus_test` должны вернуться!**

```bash
sudo -u postgres psql -d otus -c "SELECT * FROM test;"
```

Данные на месте.
