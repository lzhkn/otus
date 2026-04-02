# MySQL GTID репликация на Ubuntu 24.04

## Схема стенда

| Роль        | Hostname      | IP            |
|-------------|---------------|---------------|
| **Master**  | mysql-master  | 192.168.0.153 |
| **Replica** | mysql-replica | 192.168.0.154 |


**Цель:** настроить GTID-репликацию базы `bet`, чтобы реплицировались только таблицы: `bookmaker`, `competition`, `market`, `odds`, `outcome`. Таблицы `events_on_demand` и `v_same_event` — игнорируются.

---

## Подготовка  ВМ

Выполнить на **обеих** машинах.

### Ставим MySQL 8

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install mysql-server mysql-client -y
sudo systemctl enable --now mysql
sudo systemctl status mysql
```

### Безопасная настройка

```bash
sudo mysql_secure_installation
```

Саоздаем пароль root вручную:

```bash
sudo mysql -e "ALTER USER 'root'@'localhost' IDENTIFIED WITH caching_sha2_password BY 'password;"
```

### Проверяем подключение

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "SELECT VERSION();"
```

### Настраеваем /etc/hosts (на обеих ВМ)

```bash
sudo nano/etc/hosts 
192.168.0.153 mysql-master
192.168.0.154 mysql-replica
 
```

### Открываем порт MySQL (на обеих ВМ)

```bash
sudo ufw allow from 192.168.0.0/24 to any port 3306
```

---

##  Настраиваем Master (192.168.0.153)

###  Конфиг MySQL

```bash
sudo nano /etc/mysql/mysql.conf.d/mysqld.cnf
bind-address = 0.0.0.0
```

```bash
sudo systemctl restart mysql
```

```bash
sudo nano /etc/mysql/mysql.conf.d/replication.cnf 
[mysqld]
server-id = 1
log-bin = mysql-bin
binlog_format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON
log-replica-updates = ON
 
```

### Перезапуск MySQL

```bash
sudo systemctl restart mysql
```

### Проверка настроек

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "
SELECT @@server_id;
SHOW VARIABLES LIKE 'gtid_mode';
SHOW VARIABLES LIKE 'log_bin';
"
```

Ожидаемый результат: `server_id = 1`, `gtid_mode = ON`, `log_bin = ON`.

### Создание базы bet и загрузка дампа

Дамп `bet.dmp` сделан из Percona 5.7 (база `bet_odds`). Содержит 6 таблиц и 1 VIEW:

- **Таблицы:** `bookmaker`, `competition`, `events_on_demand`, `market`, `odds`, `outcome`
- **VIEW:** `v_same_event` (с DEFINER=`betscraper`@`%` — этого юзера нет на нашем сервере)

Копируем дамп на мастер и загружаем:

```bash
# Копируем дамп на сервер
# scp bet.dmp /tmp/bet.dmp

# Создаём базу
mysql -uroot -p'Otus2024Lab#mysql' -e "CREATE DATABASE bet;"

# Перед загрузкой — создаём пользователя-дефайнера для VIEW,
# иначе будет ошибка при создании v_same_event
mysql -uroot -p'Otus2024Lab#mysql' <<' '
CREATE USER IF NOT EXISTS 'betscraper'@'%' IDENTIFIED BY 'TmpPass123!';
GRANT ALL ON bet.* TO 'betscraper'@'%';
 

# Загружаем дамп
mysql -uroot -p'Otus2024Lab#mysql' -D bet < ./bet.dmp
```

> **Примечание:** Дамп из Percona 5.7 содержит RocksDB-специфичные команды (`rocksdb_bulk_load`). MySQL 8 их благополучно игнорирует благодаря conditional comments (`/*!50717 ... */`).

### Проверка таблиц

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "USE bet; SHOW TABLES;"
```

Должно быть 6 таблиц + 1 VIEW:

```
+------------------------------+
| Tables_in_bet                |
+------------------------------+
| bookmaker                    |
| competition                  |
| events_on_demand             |
| market                       |
| odds                         |
| outcome                      |
| v_same_event                 |
+------------------------------+
```

### Создаем пользователя для репликации

```bash
mysql -uroot -p'Otus2024Lab#mysql' <<' '
CREATE USER 'repl'@'%' IDENTIFIED WITH caching_sha2_password BY 'Repl#2024';
GRANT REPLICATION SLAVE ON *.* TO 'repl'@'%';
FLUSH PRIVILEGES;
SELECT user, host FROM mysql.user WHERE user='repl';
 
```

### Дампим базу для реплики

Ключевые моменты:

- `--source-data` — записывает позицию бинлога в дамп (аналог `--master-data` в старых версиях)
- `--ignore-table` — исключаем таблицы, которые не нужны на реплике

```bash
mysqldump -uroot -p'Otus2024Lab#mysql' \
    --all-databases \
    --triggers \
    --routines \
    --events \
    --source-data \
    --ignore-table=bet.events_on_demand \
    --ignore-table=bet.v_same_event \
    > /tmp/master.sql
```

### Копируем дамп на реплику

```bash
scp /tmp/master.sql 192.168.0.154:/tmp/master.sql
```

---

## Настраеваем Replica (192.168.0.154)

### Конфиг MySQL

```bash
sudo nano /etc/mysql/mysql.conf.d/replication.cnf 
[mysqld]
server-id = 2
log-bin = mysql-bin
relay-log = relay-log-server
binlog_format = ROW
gtid-mode = ON
enforce-gtid-consistency = ON
log-replica-updates = ON
read-only = ON

# Игнорируем таблицы при репликации
replicate-ignore-table = bet.events_on_demand
replicate-ignore-table = bet.v_same_event
 
```

```bash
sudo systemctl restart mysql
```

### Проверяем настройки

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "
SELECT @@server_id;
SHOW VARIABLES LIKE 'gtid_mode';
SHOW VARIABLES LIKE 'read_only';
"
```

Ожидаемый результат: `server_id = 2`, `gtid_mode = ON`, `read_only = ON`.

### Загружаем дамп с мастера

```bash
mysql -uroot -p'Otus2024Lab#mysql' < /tmp/master.sql
```

### Проверяем — таблиц events_on_demand и v_same_event быть не должно

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "USE bet; SHOW TABLES;"
```

Ожидаемый результат — 5 таблиц:

```
+---------------------+
| Tables_in_bet       |
+---------------------+
| bookmaker           |
| competition         |
| market              |
| odds                |
| outcome             |
+---------------------+
```

### Настройка подключения к мастеру (GTID)

```bash
mysql -uroot -p'Otus2024Lab#mysql' <<' '
STOP REPLICA;

CHANGE REPLICATION SOURCE TO
    SOURCE_HOST = '192.168.0.153',
    SOURCE_PORT = 3306,
    SOURCE_USER = 'repl',
    SOURCE_PASSWORD = 'Repl#2024',
    SOURCE_AUTO_POSITION = 1,
    GET_SOURCE_PUBLIC_KEY = 1;

START REPLICA;
 
```

> **Примечание:** `GET_SOURCE_PUBLIC_KEY = 1` нужен для аутентификации `caching_sha2_password` при первом подключении.

### 3.7 Проверка статуса репликации

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "SHOW REPLICA STATUS\G"
```

Проверяем:

```
            Last_IO_Error:                     <-- должно быть пусто
            Last_SQL_Error:                    <-- должно быть пусто
```


---

##  Проверка репликации

### На мастере — вставляем запись

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "
USE bet;
INSERT INTO bookmaker (id, bookmaker_name) VALUES (1, '1xbet');
SELECT * FROM bookmaker;
"
```

Ожидаемый результат:

```
+----+----------------+
| id | bookmaker_name |
+----+----------------+
|  1 | 1xbet          |
|  4 | betway         |
|  5 | bwin           |
|  6 | ladbrokes      |
|  3 | unibet         |
+----+----------------+
```

### На реплике — проверяем что запись появилась

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "
USE bet;
SELECT * FROM bookmaker;
"
```

Та же запись `1xbet` появилась на реплике.

### Проверка игнорирования таблиц

На мастере — вставляем в `events_on_demand` (эта таблица существует только на мастере):

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "
USE bet;
INSERT INTO events_on_demand (id) VALUES (99999);
"
```

На реплике — `events_on_demand` была исключена из дампа и из репликации. Ошибок быть не должно:

```bash
mysql -uroot -p'Otus2024Lab#mysql' -e "SHOW REPLICA STATUS\G" | grep -E "Running|Error|Ignore"
```

Результат:

```
Replica_IO_Running: Yes
Replica_SQL_Running: Yes
Replicate_Ignore_Table: bet.events_on_demand,bet.v_same_event
```

