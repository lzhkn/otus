# Домашнее задание: iptables — Port Knocking, NAT, Port Forward

## Цель

На базе лаборатории `19.network_arch` добавить:

- **Port knocking** — `centralRouter` попадает на SSH `inetRouter` только после
  правильной последовательности стуков
- **inetRouter2** — новый роутер, виден с хоста напрямую (host-only сеть)
- **nginx на centralServer**
- **Проброс порта** — `inetRouter2:8080` → `centralServer:80`
- Дефолтный маршрут в интернет остаётся через `inetRouter`

---

## Окружение

| Хост          | ens18 (mgmt/wan)  | ens19 (lan)        | Роль                           |
|---------------|-------------------|--------------------|--------------------------------|
| inetRouter    | 192.168.0.130/24  | 192.168.255.1/30   | NAT · knockd слушает **ens19** |
| inetRouter2   | 192.168.0.137/24  | —                  | DNAT :8080 → centralServer:80  |
| centralRouter | 192.168.0.131/24  | 192.168.255.2/30   | маршрутизация · knock-клиент   |
| centralServer | 192.168.0.134/24  | 192.168.0.2/28     | nginx :80                      |

> inetRouter2 и centralServer находятся в одной сети `192.168.0.0/24`,
> поэтому DNAT и MASQUERADE на inetRouter2 работают через **ens18**, не ens19.

OS: Ubuntu 24.04 LTS, Proxmox

---

## Структура проекта

```
20.iptables/
├── hosts
├── provision.yml
├── group_vars/
│   └── all.yml
└── templates/
    ├── inetRouter.iptables.j2      # NAT + INPUT DROP (SSH закрыт)
    ├── inetRouter2.iptables.j2     # DNAT :8080 → centralServer:80
    ├── knockd.conf.j2              # knockd слушает ens19 (lan, не wan!)
    ├── knock.sh.j2                 # скрипт-клиент на centralRouter
    └── centralServer.route.j2      # дефолтный маршрут через centralRouter
```

---

## Часть 1 — inetRouter: NAT + Port Knocking

### Топология интерфейсов

```
Internet ──── ens18 (wan) ──── inetRouter ──── ens19 (lan) ──── centralRouter
                                                192.168.255.1    192.168.255.2
```

knockd слушает **ens19** — стуки приходят от centralRouter (192.168.255.2)
по транзитной сети. Если указать ens18 — knockd не увидит пакеты.

### Установка

```bash
sudo apt update
sudo apt install -y iptables iptables-persistent knockd
```

### /etc/iptables/rules.v4

```
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT

# SSH закрыт — knockd вставит правило -I INPUT 1 после стука

-A FORWARD -i ens19 -o ens18 -j ACCEPT
-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT

COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

-A POSTROUTING ! -d 192.168.0.0/16 -o ens18 -j MASQUERADE

COMMIT
```

```bash
sudo iptables-restore < /etc/iptables/rules.v4
sudo netfilter-persistent save
```

### IP forwarding

```bash
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl --system
```

### /etc/knockd.conf

> **Важно:** `command` — строго одна строка, без `\`. knockd не поддерживает
> перенос строки и падает с `config: syntax error`.

```
[options]
    logfile     = /var/log/knockd.log
    interface   = ens19

[openSSH]
    sequence    = 7000,8000,9000
    seq_timeout = 10
    command     = /sbin/iptables -I INPUT 1 -s %IP% -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
    tcpflags    = syn

[closeSSH]
    sequence    = 9000,8000,7000
    seq_timeout = 10
    command     = /sbin/iptables -D INPUT -s %IP% -p tcp --dport 22 -m conntrack --ctstate NEW -j ACCEPT
    tcpflags    = syn
```

### /etc/default/knockd

```
START_KNOCKD=1
KNOCKD_OPTS="-i ens19"
```

```bash
sudo systemctl enable --now knockd
sudo systemctl status knockd
```

---

## Часть 2 — centralRouter: скрипт knock.sh

```bash
sudo apt install -y nmap
sudo nano /usr/local/bin/knock.sh
```

```bash
#!/bin/bash
TARGET="${2:-192.168.255.1}"
ACTION="${1:-open}"

knock_ports() {
    local host="$1"; shift
    for port in "$@"; do
        nmap -Pn --host-timeout 100ms -p "$port" "$host" > /dev/null 2>&1
        sleep 0.3
    done
}

if [[ "$ACTION" == "close" ]]; then
    echo "Closing SSH on ${TARGET}..."
    knock_ports "$TARGET" 9000 8000 7000
else
    echo "Knocking SSH open on ${TARGET}..."
    knock_ports "$TARGET" 7000 8000 9000
    echo "Done. ssh lzhkn@${TARGET}"
fi
```

```bash
sudo chmod +x /usr/local/bin/knock.sh
```

---

## Часть 3 — inetRouter2: DNAT :8080 → centralServer:80

inetRouter2 (192.168.0.137) и centralServer (192.168.0.2) находятся
в одной сети 192.168.0.0/24. Весь трафик идёт через **ens18**.

```bash
sudo apt update
sudo apt install -y iptables iptables-persistent
echo 'net.ipv4.ip_forward = 1' | sudo tee /etc/sysctl.d/99-forward.conf
sudo sysctl --system
```

### /etc/iptables/rules.v4

> **Важно:** MASQUERADE на **ens18** (не ens19). Оба хоста в одной /24,
> пакет уходит через ens18. Если поставить ens19 — MASQUERADE не сработает
> и ответ от centralServer уйдёт мимо.

```
*filter
:INPUT DROP [0:0]
:FORWARD DROP [0:0]
:OUTPUT ACCEPT [0:0]

-A INPUT -i lo -j ACCEPT
-A INPUT -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A INPUT -p icmp --icmp-type echo-request -j ACCEPT
-A INPUT -p tcp --dport 22   -j ACCEPT
-A INPUT -p tcp --dport 8080 -j ACCEPT

-A FORWARD -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
-A FORWARD -p tcp -d 192.168.0.2 --dport 80 -m conntrack --ctstate NEW,ESTABLISHED,RELATED -j ACCEPT

COMMIT

*nat
:PREROUTING ACCEPT [0:0]
:POSTROUTING ACCEPT [0:0]

-A PREROUTING -i ens18 -p tcp --dport 8080 -j DNAT --to-destination 192.168.0.2:80
-A POSTROUTING -o ens18 -p tcp --dport 80 -d 192.168.0.2 -j MASQUERADE

COMMIT
```

```bash
sudo iptables-restore < /etc/iptables/rules.v4
sudo netfilter-persistent save
```

---

## Часть 4 — centralServer: nginx + маршрут

```bash
sudo apt update
sudo apt install -y nginx
```

> **Важно:** на хостах с `ipv6.disable=1` nginx падает при старте:
> `socket() [::]:80 failed (97: Address family not supported)`.
> Нужно закомментировать IPv6 строку до запуска.

```bash
sudo sed -i 's/^\s*listen \[::\]:80.*$/# &/' /etc/nginx/sites-enabled/default
sudo systemctl enable --now nginx
```

### /etc/netplan/99-routes.yaml

```yaml
network:
  version: 2
  ethernets:
    ens19:
      routes:
        - to: default
          via: 192.168.255.2
```

```bash
sudo chmod 600 /etc/netplan/99-routes.yaml
sudo netplan apply
ip route show default
# Ожидаем: default via 192.168.255.2 dev ens19
```

---

## Часть 5 — Проверка

### 5.1 Port Knocking

```bash
# 1. SSH без стука — должен зависнуть/отказать (с centralRouter)
ssh lzhkn@192.168.255.1
# → timeout (INPUT DROP работает)

# 2. Стук (с centralRouter)
/usr/local/bin/knock.sh

# 3. SSH после стука
ssh lzhkn@192.168.255.1
# → успех

# 4. Лог на inetRouter
sudo tail /var/log/knockd.log
# → openSSH: Stage 1 / Stage 2 / Stage 3
# → openSSH: OPEN SESAME
# → running command: iptables -I INPUT 1 -s 192.168.255.2 ...

# 5. Закрыть SSH
/usr/local/bin/knock.sh close
```

| Проверка | Ожидаемый результат |
|---|---|
| SSH без knock | timeout |
| SSH после knock.sh | ✅ соединение |
| knockd лог | OPEN SESAME, 3 стадии |
| SSH после knock.sh close | timeout |

### 5.2 Port Forward

```bash
# DNAT правило на inetRouter2
sudo iptables -t nat -nvL PREROUTING
# → DNAT tcp dpt:8080 to:192.168.0.2:80

# С хоста (ноута)
curl http://192.168.0.137:8080
# → Welcome to nginx!
```

### 5.3 Дефолтный маршрут

```bash
# На любом хосте лабы
traceroute -n -m4 8.8.8.8
# Хоп 1: 192.168.255.1 (inetRouter) — НЕ inetRouter2
```

### 5.4 Персистентность после ребута

```bash
sudo reboot

# После загрузки — inetRouter
sudo iptables-save | grep MASQUERADE
sudo systemctl status knockd

# inetRouter2
sudo iptables -t nat -nvL PREROUTING
```

---

## устанвока через Ansible

```bash
ansible -i hosts all -m ping --ask-become
ansible-playbook -i hosts provision.yml --ask-become
```

