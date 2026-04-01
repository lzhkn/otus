# Домашнее задание: VPN

## Описание

1. Настроить VPN между двумя ВМ в tun/tap режимах, замерить скорость в туннелях, сделать вывод об отличающихся показателях.
2. Поднять RAS на базе OpenVPN с клиентскими сертификатами, подключиться с локальной машины на ВМ.

## Стенд

```
server-01: 192.168.0.150  (Ubuntu)
server-02: 192.168.0.151  (Ubuntu)
```

## Схема сети

```
┌───────────────────────┐              ┌───────────────────────┐
│     server-01         │              │     server-02         │
│   192.168.0.150       │◄────────────►│   192.168.0.151       │
│                       │     LAN      │                       │
│  TAP: 10.10.10.1/24   │ ~~~~~~~~~~~  │  TAP: 10.10.10.2/24   │
│  TUN: 10.10.10.1 p2p  │ ~~~~~~~~~~~  │  TUN: 10.10.10.2 p2p  │
│  RAS: 10.10.10.1/24   │ ~~~~~~~~~~~  │  RAS-клиент            │
│       порт 1207/udp   │              │                       │
└───────────────────────┘              └───────────────────────┘
```

---

# Задание 1: TUN/TAP режимы VPN

## 1.1. Установка пакетов (на обоих хостах)

```bash
sudo apt update
sudo apt install -y openvpn iperf3
```

## 1.2. Генерация статического ключа (server-01)

```bash
sudo openvpn --genkey secret /etc/openvpn/static.key
```

## 1.3. Копирование ключа на клиент (server-02)

```bash
scp /etc/openvpn/static.key root@192.168.0.151:/etc/openvpn/static.key
```

На server-02 выставляем права:

```bash
sudo chmod 600 /etc/openvpn/static.key
```

---

## 1.4. Режим TAP (L2-туннель)

### server-01 — конфигурация

```bash
sudo nano /etc/openvpn/server-tap.conf  
dev tap
ifconfig 10.10.10.1 255.255.255.0
topology subnet
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status-tap.log
log /var/log/openvpn-tap.log
verb 3

```

### server-02 — конфигурация

```bash
sudo nano /etc/openvpn/client-tap.conf  
dev tap
remote 192.168.0.150
ifconfig 10.10.10.2 255.255.255.0
topology subnet
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status-tap.log
log /var/log/openvpn-tap.log
verb 3

```

### Создание systemd-юнита (на обоих хостах)

```bash
sudo nano /etc/systemd/system/openvpn@.service  
[Unit]
Description=OpenVPN Tunneling Application On %I
After=network.target

[Service]
Type=notify
PrivateTmp=true
ExecStart=/usr/sbin/openvpn --cd /etc/openvpn/ --config %i.conf

[Install]
WantedBy=multi-user.target


sudo systemctl daemon-reload
```

### Запуск TAP

```bash
# server-01
sudo systemctl start openvpn@server-tap
sudo systemctl enable openvpn@server-tap

# server-02
sudo systemctl start openvpn@client-tap
sudo systemctl enable openvpn@client-tap
```

### Проверка TAP

```bash
# server-02
ping -c 4 10.10.10.1
ip a show tap0
```

### Замер скорости TAP

```bash
# server-01 — iperf3 в режиме сервера
iperf3 -s &

# server-02 — замер (40 сек, отчёт каждые 5 сек)
iperf3 -c 10.10.10.1 -t 40 -i 5
```

> Записываем результат — он понадобится для сравнения.

### Остановка TAP перед переключением

```bash
# server-01
sudo systemctl stop openvpn@server-tap

# server-02
sudo systemctl stop openvpn@client-tap
```

---

## 1.5. Режим TUN (L3-туннель)

### server-01 — конфигурация

```bash
sudo nano /etc/openvpn/server-tun.conf  
dev tun
ifconfig 10.10.10.1 10.10.10.2
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status-tun.log
log /var/log/openvpn-tun.log
verb 3

```

### server-02 — конфигурация

```bash
sudo nano /etc/openvpn/client-tun.conf  
dev tun
remote 192.168.0.150
ifconfig 10.10.10.2 10.10.10.1
secret /etc/openvpn/static.key
comp-lzo
status /var/log/openvpn-status-tun.log
log /var/log/openvpn-tun.log
verb 3

```

### Запуск TUN

```bash
# server-01
sudo systemctl start openvpn@server-tun

# server-02
sudo systemctl start openvpn@client-tun
```

### Проверка TUN

```bash
# server-02
ping -c 4 10.10.10.1
ip a show tun0
```

### Замер скорости TUN

```bash
# server-01 (если iperf3 ещё работает — пропустить)
iperf3 -s &

# server-02
iperf3 -c 10.10.10.1 -t 40 -i 5
```

### Остановка TUN (после замера)

```bash
# server-01
sudo systemctl stop openvpn@server-tun
pkill iperf3

# server-02
sudo systemctl stop openvpn@client-tun
```

---

## 1.6. Выводы по TUN vs TAP

| Параметр | TAP (L2) | TUN (L3) |
|---|---|---|
| Уровень | Канальный (Ethernet) | Сетевой (IP) |
| Overhead на пакет | +14 байт (Ethernet-заголовок) | Нет дополнительного |
| Broadcast / ARP | Проходит через туннель | Не проходит |
| Пропускная способность | Чуть ниже | Чуть выше |
| Когда нужен | Мосты, DHCP, non-IP протоколы | Маршрутизация IP |

TUN показывает более высокую пропускную способность за счёт отсутствия Ethernet-заголовков и широковещательного трафика.

---

# Задание 2: RAS на базе OpenVPN с клиентскими сертификатами

Всё ниже выполняется на **server-01** (192.168.0.150), если не указано иное.

## 2.1. Установка

```bash
sudo apt update
sudo apt install -y openvpn easy-rsa
```

## 2.2. Инициализация PKI

```bash
cd /etc/openvpn
sudo /usr/share/easy-rsa/easyrsa init-pki
```

## 2.3. Генерация CA

```bash
echo 'rasvpn' | sudo /usr/share/easy-rsa/easyrsa build-ca nopass
```

## 2.4. Сертификат и ключ сервера

```bash
echo 'server' | sudo /usr/share/easy-rsa/easyrsa gen-req server nopass
echo 'yes' | sudo /usr/share/easy-rsa/easyrsa sign-req server server
sudo /usr/share/easy-rsa/easyrsa gen-dh
```

## 2.5. Сертификат и ключ клиента

```bash
echo 'client' | sudo /usr/share/easy-rsa/easyrsa gen-req client nopass
echo 'yes' | sudo /usr/share/easy-rsa/easyrsa sign-req client client
```

## 2.6. Конфигурация RAS-сервера

```bash
sudo mkdir -p /etc/openvpn/client

echo 'iroute 10.10.10.0 255.255.255.0' | sudo nano /etc/openvpn/client/client

sudo nano /etc/openvpn/server.conf  
port 1207
proto udp
dev tun
ca /etc/openvpn/pki/ca.crt
cert /etc/openvpn/pki/issued/server.crt
key /etc/openvpn/pki/private/server.key
dh /etc/openvpn/pki/dh.pem
server 10.10.10.0 255.255.255.0
ifconfig-pool-persist ipp.txt
client-to-client
client-config-dir /etc/openvpn/client
keepalive 10 120
comp-lzo
persist-key
persist-tun
status /var/log/openvpn-status.log
log /var/log/openvpn.log
verb 3

```

## 2.7. Запуск RAS-сервера

Если systemd-юнит `openvpn@.service` уже создан в задании 1 — пропускаем.
Иначе создаём (см. раздел 1.4).

```bash
sudo systemctl start openvpn@server
sudo systemctl enable openvpn@server
```

Проверка:

```bash
sudo systemctl status openvpn@server
sudo ss -ulnp | grep 1207
```

---

## 2.8. Настройка клиента (server-02 или локальная машина)

### Копирование файлов с server-01

```bash
mkdir -p ~/openvpn-ras
scp root@192.168.0.150:/etc/openvpn/pki/ca.crt ~/openvpn-ras/
scp root@192.168.0.150:/etc/openvpn/pki/issued/client.crt ~/openvpn-ras/
scp root@192.168.0.150:/etc/openvpn/pki/private/client.key ~/openvpn-ras/
```

### Создание клиентского конфига

```bash
nano ~/openvpn-ras/client.conf  
dev tun
proto udp
remote 192.168.0.150 1207
client
resolv-retry infinite
remote-cert-tls server
ca ./ca.crt
cert ./client.crt
key ./client.key
route 192.168.0.0 255.255.255.0
persist-key
persist-tun
comp-lzo
verb 3

```

### Подключение

```bash
cd ~/openvpn-ras
sudo openvpn --config client.conf
```

### Проверка (в другом терминале)

```bash
ping -c 4 10.10.10.1
ip route | grep 10.10.10
```

---

## Диагностика

```bash
# Логи
sudo tail -f /var/log/openvpn.log
sudo journalctl -u openvpn@server -f

# Интерфейсы
ip a | grep -E 'tap|tun'

# Порты
sudo ss -ulnp | grep -E '1194|1207'

# Firewall
sudo ufw allow 1194/udp
sudo ufw allow 1207/udp
```


