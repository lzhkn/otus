# DNS и Split-DNS — ручная настройка на Ubuntu 24.04 (PVE)

## Схема стенда

```
┌────────────────────────────────────────────────────────────┐
│                   PVE / 192.168.0.0/24                     │
│                   GW: 192.168.0.32                         │
│                                                            │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐  ┌────────────┐│
│  │  ns-01   │  │  ns-02   │  │ns-client-01│  │ns-client-02││
│  │  master  │  │  slave   │  │  client 1  │  │  client 2  ││
│  │ .0.146   │  │ .0.147   │  │  .0.148    │  │  .0.149    ││
│  └──────────┘  └──────────┘  └────────────┘  └────────────┘│
└────────────────────────────────────────────────────────────┘
```

| Хост         | IP            | Роль               |
|--------------|---------------|--------------------|
| ns-01        | 192.168.0.146 | Master DNS (BIND9) |
| ns-02        | 192.168.0.147 | Slave DNS (BIND9)  |
| ns-client-01 | 192.168.0.148 | DNS-клиент 1       |
| ns-client-02 | 192.168.0.149 | DNS-клиент 2       |

## Задание

**Часть 1 — Базовый DNS:**
- В зоне `dns.lab`: `web1` → 192.168.0.148 (client1), `web2` → 192.168.0.149 (client2)
- Новая зона `newdns.lab`: `www` → оба клиента (192.168.0.148 и 192.168.0.149)

**Часть 2 — Split-DNS:**
- client1 — видит обе зоны, но в dns.lab только `web1` (web2 скрыт)
- client2 — видит только `dns.lab` (полностью), `newdns.lab` не видит

---

## Подготовка всех хостов

СТавим на всех 4-х машинах:

```bash
apt update && apt install -y bind9 bind9-utils dnsutils
```

На серверах (ns-01, ns-02) BIND будет работать как DNS-сервер.
На клиентах пакеты нужны для утилит `dig`, `nslookup`.

Создаем каталог для логов BIND на обоих серверах (ns-01, ns-02):

```bash
mkdir -p /var/cache/bind/data
chown bind:bind /var/cache/bind/data
```

---

## Часть 1. Базовая настройка DNS

### Генерруем ключ для zone transfer

На **ns-01**:

```bash
tsig-keygen -a hmac-sha256 zonetransfer.key
```


```
key "zonetransfer.key" {
    algorithm hmac-sha256;
    secret "igYIqtJpv/GwrolShg69UlbO/ziRESTCpQXbv8D2Mio=";
};
```

Сохраняем этот блок — он пойдёт в файл `/etc/bind/named.zonetransfer.key` на **обоих** серверах.

Создаем файл на **ns-01** и на **ns-02**:

```bash
nano /etc/bind/named.zonetransfer.key 
key "zonetransfer.key" {
    algorithm hmac-sha256;
    secret "igYIqtJpv/GwrolShg69UlbO/ziRESTCpQXbv8D2Mio=";
};
 

chown root:bind /etc/bind/named.zonetransfer.key
chmod 644 /etc/bind/named.zonetransfer.key
```

### Конфигурация ns-01 (master)

Файл `/etc/bind/named.conf`:

```bash
nano /etc/bind/named.conf 
options {
    listen-on port 53 { 192.168.0.146; 127.0.0.1; };
    listen-on-v6 port 53 { ::1; };

    directory       "/var/cache/bind";
    dump-file       "/var/cache/bind/cache_dump.db";
    statistics-file "/var/cache/bind/named_stats.txt";
    memstatistics-file "/var/cache/bind/named_mem_stats.txt";

    recursion yes;
    allow-query { any; };
    allow-transfer { any; };

    dnssec-validation auto;

    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";

    forwarders { 192.168.0.32; };
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

// ZONE TRANSFER KEY
include "/etc/bind/named.zonetransfer.key";

server 192.168.0.147 {
    keys { "zonetransfer.key"; };
};

// Standard zones
include "/etc/bind/named.conf.default-zones";

// dns.lab zone
zone "dns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/zones/dns.lab";
};

// Reverse zone
zone "0.168.192.in-addr.arpa" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/zones/dns.lab.rev";
};

// newdns.lab zone
zone "newdns.lab" {
    type master;
    allow-transfer { key "zonetransfer.key"; };
    file "/etc/bind/zones/newdns.lab";
};
 
```

### Создаем каталог и файлы зон на ns-01

```bash
mkdir -p /etc/bind/zones
```

#### Файл зоны dns.lab

```bash
nano /etc/bind/zones/dns.lab 
$TTL 3600
$ORIGIN dns.lab.
@       IN  SOA ns01.dns.lab. root.dns.lab. (
            2025040201  ; serial
            3600        ; refresh (1 hour)
            600         ; retry (10 minutes)
            86400       ; expire (1 day)
            600         ; minimum (10 minutes)
        )

        IN  NS  ns01.dns.lab.
        IN  NS  ns02.dns.lab.

; DNS Servers
ns01    IN  A   192.168.0.146
ns02    IN  A   192.168.0.147

; Web
web1    IN  A   192.168.0.148
web2    IN  A   192.168.0.149
 
```

#### Файл обратной зоны

```bash
nano /etc/bind/zones/dns.lab.rev 
$TTL 3600
$ORIGIN 0.168.192.in-addr.arpa.
@       IN  SOA ns01.dns.lab. root.dns.lab. (
            2025040201  ; serial
            3600        ; refresh
            600         ; retry
            86400       ; expire
            600         ; minimum
        )

        IN  NS  ns01.dns.lab.
        IN  NS  ns02.dns.lab.

146     IN  PTR ns01.dns.lab.
147     IN  PTR ns02.dns.lab.
148     IN  PTR web1.dns.lab.
149     IN  PTR web2.dns.lab.
 
```

#### Файл зоны newdns.lab

```bash
nano /etc/bind/zones/newdns.lab 
$TTL 3600
$ORIGIN newdns.lab.
@       IN  SOA ns01.dns.lab. root.dns.lab. (
            2025040201  ; serial
            3600        ; refresh
            600         ; retry
            86400       ; expire
            600         ; minimum
        )

        IN  NS  ns01.dns.lab.
        IN  NS  ns02.dns.lab.

; DNS Servers
ns01    IN  A   192.168.0.146
ns02    IN  A   192.168.0.147

; WWW — указывает на обоих клиентов
www     IN  A   192.168.0.148
www     IN  A   192.168.0.149
 
```

#### Установливаем права

```bash
chown -R root:bind /etc/bind/zones
chmod 660 /etc/bind/zones/*
```

### Конфигурируем ns-02 (slave)

Файл `/etc/bind/named.conf`:

```bash
nano /etc/bind/named.conf 
options {
    listen-on port 53 { 192.168.0.147; 127.0.0.1; };
    listen-on-v6 port 53 { ::1; };

    directory       "/var/cache/bind";
    dump-file       "/var/cache/bind/cache_dump.db";
    statistics-file "/var/cache/bind/named_stats.txt";
    memstatistics-file "/var/cache/bind/named_mem_stats.txt";

    recursion yes;
    allow-query { any; };
    allow-transfer { any; };

    dnssec-validation auto;

    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";

    forwarders { 192.168.0.32; };
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

// ZONE TRANSFER KEY
include "/etc/bind/named.zonetransfer.key";

server 192.168.0.146 {
    keys { "zonetransfer.key"; };
};

// Standard zones
include "/etc/bind/named.conf.default-zones";

// dns.lab zone
zone "dns.lab" {
    type slave;
    masters { 192.168.0.146; };
    file "/var/cache/bind/dns.lab";
};

// Reverse zone
zone "0.168.192.in-addr.arpa" {
    type slave;
    masters { 192.168.0.146; };
    file "/var/cache/bind/dns.lab.rev";
};

// newdns.lab zone
zone "newdns.lab" {
    type slave;
    masters { 192.168.0.146; };
    file "/var/cache/bind/newdns.lab";
};
 
```

### Проверяем конфигурации и запуск

На **ns-01**:

```bash
named-checkconf
named-checkzone dns.lab /etc/bind/zones/dns.lab
named-checkzone newdns.lab /etc/bind/zones/newdns.lab
named-checkzone 0.168.192.in-addr.arpa /etc/bind/zones/dns.lab.rev
systemctl restart named
systemctl enable named
```

На **ns-02**:

```bash
named-checkconf
systemctl restart named
systemctl enable named
```

### Настроеваем resolv.conf на клиентах

На **ns-client-01** и **ns-client-02** — отключаем systemd-resolved и прописываем наши DNS:

```bash
systemctl disable --now systemd-resolved
rm -f /etc/resolv.conf

nano /etc/resolv.conf 
domain dns.lab
search dns.lab newdns.lab
nameserver 192.168.0.146
nameserver 192.168.0.147
 
```

На **ns-01**:
```bash
systemctl disable --now systemd-resolved
rm -f /etc/resolv.conf

nano /etc/resolv.conf 
domain dns.lab
search dns.lab
nameserver 192.168.0.146
 
```

На **ns-02**:
```bash
systemctl disable --now systemd-resolved
rm -f /etc/resolv.conf

nano /etc/resolv.conf 
domain dns.lab
search dns.lab
nameserver 192.168.0.147
 
```

### Проверяем базовую работу днс

С любого клиента:

```bash
dig @192.168.0.146 web1.dns.lab +short
dig @192.168.0.146 web2.dns.lab +short
dig @192.168.0.147 web1.dns.lab +short
dig @192.168.0.146 www.newdns.lab +short
dig @192.168.0.147 www.newdns.lab +short
dig @192.168.0.146 -x 192.168.0.148 +short
```

**Ожидаемый результат:**
- `web1.dns.lab` → 192.168.0.148
- `web2.dns.lab` → 192.168.0.149
- `www.newdns.lab` → 192.168.0.148 и 192.168.0.149 (round-robin)
- Обратная зона: 192.168.0.148 → `web1.dns.lab`

---

## Часть 2. Настройка Split-DNS

### Генерируем TSIG-ключи для клиентов

На **ns-01**:

```bash
tsig-keygen -a hmac-sha256 client-key
tsig-keygen -a hmac-sha256 client2-key
```

Сохраняем оба ключа (значение `secret`) — они понадобятся далее.

> ** при вставке ключей:** нужно убедиться, что значение secret заключено ровно в одну пару кавычек, например: `secret "abc123def=";` — без дублирования кавычек на конце! Почему-то первый раз секрет сгенерировался с лишней кавычкой, что принесло не мало попаболи.

### Создаем урезанную зону dns.lab для client1

На **ns-01** — файл, в котором есть только `web1` (без `web2`):

```bash
nano /etc/bind/zones/dns.lab.client 
$TTL 3600
$ORIGIN dns.lab.
@       IN  SOA ns01.dns.lab. root.dns.lab. (
            2025040201  ; serial
            3600        ; refresh
            600         ; retry
            86400       ; expire
            600         ; minimum
        )

        IN  NS  ns01.dns.lab.
        IN  NS  ns02.dns.lab.

; DNS Servers
ns01    IN  A   192.168.0.146
ns02    IN  A   192.168.0.147

; Web — только web1!
web1    IN  A   192.168.0.148
 

chown root:bind /etc/bind/zones/dns.lab.client
chmod 660 /etc/bind/zones/dns.lab.client
```

### Новый named.conf для ns-01 (master) с view

**Полностью заменяем** `/etc/bind/named.conf` на ns-01:

```bash
nano /etc/bind/named.conf 
options {
    listen-on port 53 { 192.168.0.146; 127.0.0.1; };
    listen-on-v6 port 53 { ::1; };

    directory       "/var/cache/bind";
    dump-file       "/var/cache/bind/cache_dump.db";
    statistics-file "/var/cache/bind/named_stats.txt";
    memstatistics-file "/var/cache/bind/named_mem_stats.txt";

    recursion yes;
    allow-query { any; };
    allow-transfer { any; };

    dnssec-validation auto;

    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";

    forwarders { 192.168.0.32; };
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

// ZONE TRANSFER KEY
include "/etc/bind/named.zonetransfer.key";

server 192.168.0.147 {
    keys { "zonetransfer.key"; };
};

// ===== TSIG-ключи для клиентов =====
key "client-key" {
    algorithm hmac-sha256;
    secret "n8yPdW1mj/7g6CIFqBP4c+RYepDFu7kKQVyAAQ0QhQI=";
};

key "client2-key" {
    algorithm hmac-sha256;
    secret "Db/YbLTsDXcKzvEKxhm8ZLFnMO81b2xq5dlbXzhfOw8=";
};

// ===== ACL =====
acl client  { !key client2-key; key client-key;  192.168.0.148; };
acl client2 { !key client-key;  key client2-key; 192.168.0.149; };

// =============================================
// VIEW для client1:
//   - dns.lab (только web1 — урезанная зона)
//   - newdns.lab (полная)
// =============================================
view "client" {
    match-clients { client; };

    zone "dns.lab" {
        type master;
        file "/etc/bind/zones/dns.lab.client";
        also-notify { 192.168.0.147 key client-key; };
    };

    zone "newdns.lab" {
        type master;
        file "/etc/bind/zones/newdns.lab";
        also-notify { 192.168.0.147 key client-key; };
    };
};

// =============================================
// VIEW для client2:
//   - dns.lab (полная зона, web1 + web2)
//   - БЕЗ newdns.lab!
// =============================================
view "client2" {
    match-clients { client2; };

    zone "dns.lab" {
        type master;
        file "/etc/bind/zones/dns.lab";
        also-notify { 192.168.0.147 key client2-key; };
    };

    zone "0.168.192.in-addr.arpa" {
        type master;
        file "/etc/bind/zones/dns.lab.rev";
        also-notify { 192.168.0.147 key client2-key; };
    };
};

// =============================================
// VIEW по умолчанию (для всех остальных, включая slave)
// =============================================
view "default" {
    match-clients { any; };

    // Standard zones (включает корневую зону)
    include "/etc/bind/named.conf.default-zones";

    // dns.lab zone
    zone "dns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/bind/zones/dns.lab";
    };

    // Reverse zone
    zone "0.168.192.in-addr.arpa" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/bind/zones/dns.lab.rev";
    };

    // newdns.lab zone
    zone "newdns.lab" {
        type master;
        allow-transfer { key "zonetransfer.key"; };
        file "/etc/bind/zones/newdns.lab";
    };
};

```

### Новый named.conf для ns-02 (slave) с view

**Полностью заменяем** `/etc/bind/named.conf` на ns-02:

```bash
nano /etc/bind/named.conf 
options {
    listen-on port 53 { 192.168.0.147; 127.0.0.1; };
    listen-on-v6 port 53 { ::1; };

    directory       "/var/cache/bind";
    dump-file       "/var/cache/bind/cache_dump.db";
    statistics-file "/var/cache/bind/named_stats.txt";
    memstatistics-file "/var/cache/bind/named_mem_stats.txt";

    recursion yes;
    allow-query { any; };
    allow-transfer { any; };

    dnssec-validation auto;

    pid-file "/run/named/named.pid";
    session-keyfile "/run/named/session.key";

    forwarders { 192.168.0.32; };
};

logging {
    channel default_debug {
        file "data/named.run";
        severity dynamic;
    };
};

// ZONE TRANSFER KEY
include "/etc/bind/named.zonetransfer.key";

server 192.168.0.146 {
    keys { "zonetransfer.key"; };
};

// ===== TSIG-ключи для клиентов =====
key "client-key" {
    algorithm hmac-sha256;
    secret "n8yPdW1mj/7g6CIFqBP4c+RYepDFu7kKQVyAAQ0QhQI=";
};

key "client2-key" {
    algorithm hmac-sha256;
    secret "Db/YbLTsDXcKzvEKxhm8ZLFnMO81b2xq5dlbXzhfOw8=";
};

// ===== ACL =====
acl client  { !key client2-key; key client-key;  192.168.0.148; };
acl client2 { !key client-key;  key client2-key; 192.168.0.149; };

// =============================================
// VIEW для client1
// =============================================
view "client" {
    match-clients { client; };

    zone "dns.lab" {
        type slave;
        masters { 192.168.0.146 key client-key; };
        file "/var/cache/bind/dns.lab.client";
    };

    zone "newdns.lab" {
        type slave;
        masters { 192.168.0.146 key client-key; };
        file "/var/cache/bind/newdns.lab.client";
    };
};

// =============================================
// VIEW для client2
// =============================================
view "client2" {
    match-clients { client2; };

    zone "dns.lab" {
        type slave;
        masters { 192.168.0.146 key client2-key; };
        file "/var/cache/bind/dns.lab.client2";
    };

    zone "0.168.192.in-addr.arpa" {
        type slave;
        masters { 192.168.0.146 key client2-key; };
        file "/var/cache/bind/dns.lab.rev.client2";
    };
};

// =============================================
// VIEW по умолчанию
// =============================================
view "default" {
    match-clients { any; };

    // Standard zones (включает корневую зону)
    include "/etc/bind/named.conf.default-zones";

    zone "dns.lab" {
        type slave;
        masters { 192.168.0.146; };
        file "/var/cache/bind/dns.lab";
    };

    zone "0.168.192.in-addr.arpa" {
        type slave;
        masters { 192.168.0.146; };
        file "/var/cache/bind/dns.lab.rev";
    };

    zone "newdns.lab" {
        type slave;
        masters { 192.168.0.146; };
        file "/var/cache/bind/newdns.lab";
    };
};

```

> Ключи `secret` должны быть **идентичны** тем, что на ns-01. 

### О работе Split-DNS по IP (без TSIG на клиентах)

В нашей конфигурации ACL включают IP-адреса клиентов, поэтому BIND различает клиентов просто по source IP запроса. Дополнительная настройка TSIG на клиентских машинах **не требуется** — `resolv.conf` остаётся как в Части 1.

### Проверка и перезапуск

На **ns-01**:
```bash
named-checkconf
named-checkzone dns.lab /etc/bind/zones/dns.lab
named-checkzone dns.lab /etc/bind/zones/dns.lab.client
named-checkzone newdns.lab /etc/bind/zones/newdns.lab
systemctl restart named
```

На **ns-02**:
```bash
named-checkconf
systemctl restart named
```

### Проверка Split-DNS

#### С ns-client-01 (192.168.0.148):

```bash
echo "=== web1 ===" && dig @192.168.0.146 web1.dns.lab +short
echo "=== web2 ===" && dig @192.168.0.146 web2.dns.lab +short
echo "=== www.newdns ===" && dig @192.168.0.146 www.newdns.lab +short
```

Ожидаемый результат:
- `web1.dns.lab` → 192.168.0.148 ✅
- `web2.dns.lab` → пусто ❌ (скрыт)
- `www.newdns.lab` → 192.168.0.148 и .149 ✅

Проверка через slave:
```bash
echo "=== web1 ===" && dig @192.168.0.147 web1.dns.lab +short
echo "=== web2 ===" && dig @192.168.0.147 web2.dns.lab +short
echo "=== www.newdns ===" && dig @192.168.0.147 www.newdns.lab +short
```

#### С ns-client-02 (192.168.0.149):

```bash
echo "=== web1 ===" && dig @192.168.0.146 web1.dns.lab +short
echo "=== web2 ===" && dig @192.168.0.146 web2.dns.lab +short
echo "=== www.newdns ===" && dig @192.168.0.146 www.newdns.lab +short
```

Ожидаемый результат:
- `web1.dns.lab` → 192.168.0.148 ✅
- `web2.dns.lab` → 192.168.0.149 ✅
- `www.newdns.lab` → пусто ❌ (зона недоступна)

Проверка через slave:
```bash
echo "=== web1 ===" && dig @192.168.0.147 web1.dns.lab +short
echo "=== web2 ===" && dig @192.168.0.147 web2.dns.lab +short
echo "=== www.newdns ===" && dig @192.168.0.147 www.newdns.lab +short
```

---

## Сводная таблица результатов

| Запрос           | client1 (master) | client1 (slave) | client2 (master) | client2 (slave) |
|------------------|:----------------:|:---------------:|:----------------:|:---------------:|
| `web1.dns.lab`   | ✅ .148          | ✅ .148         | ✅ .148         | ✅ .148         |
| `web2.dns.lab`   | ❌ пусто         | ❌ пусто        | ✅ .149         | ✅ .149         |
| `www.newdns.lab` | ✅ .148/.149     | ✅ .148/.149    | ❌ пусто        | ❌ пусто        |

---

## Устранение проблем

**BIND не стартует:**
```bash
journalctl -u named --no-pager -n 50
named-checkconf
named-checkconf -z
named-checkzone dns.lab /etc/bind/zones/dns.lab
```

**Ошибка «permission denied» на data/named.run:**
```bash
mkdir -p /var/cache/bind/data
chown bind:bind /var/cache/bind/data
systemctl restart named
```

**Ошибка «zone '.' already exists»:**
Корневая зона объявлена дважды — и в вашем `named.conf`, и в `named.conf.default-zones`. Не добавляйте блок `zone "." IN { ... };` вручную — он уже есть в `include "/etc/bind/named.conf.default-zones";`.

**Slave не получает зоны:**
```bash
journalctl -u named | grep transfer
# Проверяем что ключ zonetransfer.key одинаковый на обоих серверах
```

**Split-DNS не работает (клиент видит не ту зону):**
```bash
rndc querylog on
journalctl -fu named
# Сделать запрос с клиента и посмотреть в какой view он попал
rndc querylog off
```

**resolv.conf сбрасывается после перезагрузки:**
```bash
systemctl status systemd-resolved
# Если работает:
systemctl disable --now systemd-resolved
rm -f /etc/resolv.conf
# Пересоздать файл вручную
```

**AppArmor мешает BIND:**
```bash
aa-status | grep named
aa-complain /usr/sbin/named
```

---

## Структура файлов

```
ns-01 (192.168.0.146):
  /etc/bind/named.conf                  — основной конфиг с view
  /etc/bind/named.zonetransfer.key      — ключ zone transfer
  /etc/bind/zones/dns.lab               — полная зона dns.lab (web1+web2)
  /etc/bind/zones/dns.lab.client        — урезанная зона dns.lab (только web1)
  /etc/bind/zones/dns.lab.rev           — обратная зона
  /etc/bind/zones/newdns.lab            — зона newdns.lab

ns-02 (192.168.0.147):
  /etc/bind/named.conf                  — конфиг slave с view
  /etc/bind/named.zonetransfer.key      — ключ zone transfer (копия с ns-01)
  /var/cache/bind/                      — сюда slave скачает зоны автоматически

ns-client-01 (192.168.0.148):
  /etc/resolv.conf                      — nameserver 192.168.0.146 + .147

ns-client-02 (192.168.0.149):
  /etc/resolv.conf                      — nameserver 192.168.0.146 + .147
```
