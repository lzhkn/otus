# Домашнее задание: Архитектура сетей

## Цель

Построить сетевую лабораторию из 7 серверов на Ubuntu 24.04 в Proxmox,
настроить маршрутизацию и NAT так, чтобы:
- весь интернет-трафик шёл через `inetRouter`
- все серверы видели друг друга

---

## Часть 1. Теория

### 1.1 Расчёт подсетей

Формула: `2^(32 - маска) - 2` хостов.

| Название           | Сеть               | Маска           | Хостов | HostMin       | HostMax        | Broadcast      |
|--------------------|--------------------|-----------------|--------|---------------|----------------|----------------|
| **Central**        |                    |                 |        |               |                |                |
| directors          | 192.168.0.0/28     | 255.255.255.240 | 14     | 192.168.0.1   | 192.168.0.14   | 192.168.0.15   |
| office hardware    | 192.168.0.32/28    | 255.255.255.240 | 14     | 192.168.0.33  | 192.168.0.46   | 192.168.0.47   |
| wifi/mgt           | 192.168.0.64/26    | 255.255.255.192 | 62     | 192.168.0.65  | 192.168.0.126  | 192.168.0.127  |
| **Office1**        |                    |                 |        |               |                |                |
| dev                | 192.168.2.0/26     | 255.255.255.192 | 62     | 192.168.2.1   | 192.168.2.62   | 192.168.2.63   |
| test servers       | 192.168.2.64/26    | 255.255.255.192 | 62     | 192.168.2.65  | 192.168.2.126  | 192.168.2.127  |
| managers           | 192.168.2.128/26   | 255.255.255.192 | 62     | 192.168.2.129 | 192.168.2.190  | 192.168.2.191  |
| office hardware    | 192.168.2.192/26   | 255.255.255.192 | 62     | 192.168.2.193 | 192.168.2.254  | 192.168.2.255  |
| **Office2**        |                    |                 |        |               |                |                |
| dev                | 192.168.1.0/25     | 255.255.255.128 | 126    | 192.168.1.1   | 192.168.1.126  | 192.168.1.127  |
| test servers       | 192.168.1.128/26   | 255.255.255.192 | 62     | 192.168.1.129 | 192.168.1.190  | 192.168.1.191  |
| office hardware    | 192.168.1.192/26   | 255.255.255.192 | 62     | 192.168.1.193 | 192.168.1.254  | 192.168.1.255  |
| **Transit**        |                    |                 |        |               |                |                |
| inetRouter—central | 192.168.255.0/30   | 255.255.255.252 | 2      | 192.168.255.1 | 192.168.255.2  | 192.168.255.3  |
| central—office2    | 192.168.255.4/30   | 255.255.255.252 | 2      | 192.168.255.5 | 192.168.255.6  | 192.168.255.7  |
| central—office1    | 192.168.255.8/30   | 255.255.255.252 | 2      | 192.168.255.9 | 192.168.255.10 | 192.168.255.11 |

#### Свободные подсети

| Подсеть             | Хостов |
|---------------------|--------|
| 192.168.0.16/28     | 14     |
| 192.168.0.48/28     | 14     |
| 192.168.0.128/25    | 126    |
| 192.168.255.12/30   | 2      |
| 192.168.255.16/28   | 14     |
| 192.168.255.32/27   | 30     |
| 192.168.255.64/26   | 62     |
| 192.168.255.128/25  | 126    |

---

### 1.2 Адресный план

| Сервер        | Интерфейс | Адрес / маска     | Назначение                |
|---------------|-----------|-------------------|---------------------------|
| inetRouter    | ens18     | 192.168.0.130/24  | mgmt + выход в интернет   |
|               | ens19     | 192.168.255.1/30  | линк до centralRouter     |
| centralRouter | ens18     | 192.168.0.131/24  | mgmt                      |
|               | ens19     | 192.168.255.2/30  | линк до inetRouter        |
|               | ens20     | 192.168.0.1/28    | directors                 |
|               | ens21     | 192.168.0.33/28   | office hardware central   |
|               | ens22     | 192.168.0.65/26   | wifi/mgt                  |
|               | ens23     | 192.168.255.9/30  | линк до office1Router     |
|               | ens24*    | 192.168.255.5/30  | линк до office2Router     |
| centralServer | ens18     | 192.168.0.134/24  | mgmt                      |
|               | ens19     | 192.168.0.2/28    | directors                 |
| office1Router | ens18     | 192.168.0.132/24  | mgmt                      |
|               | ens19     | 192.168.255.10/30 | линк до centralRouter     |
|               | ens20     | 192.168.2.1/26    | dev                       |
|               | ens21     | 192.168.2.65/26   | test servers              |
|               | ens22     | 192.168.2.129/26  | managers                  |
|               | ens23     | 192.168.2.193/26  | office hardware           |
| office1Server | ens18     | 192.168.0.135/24  | mgmt                      |
|               | ens19     | 192.168.2.130/26  | managers                  |
| office2Router | ens18     | 192.168.0.133/24  | mgmt                      |
|               | ens19     | 192.168.255.6/30  | линк до centralRouter     |
|               | ens20     | 192.168.1.1/25    | dev                       |
|               | ens21     | 192.168.1.129/26  | test servers              |
|               | ens22     | 192.168.1.193/26  | office hardware           |
| office2Server | ens18     | 192.168.0.136/24  | mgmt                      |
|               | ens19     | 192.168.1.2/25    | dev                       |

> *ens24 на centralRouter физически называется `enp2s1` из-за PCI-слота в Proxmox.
> Зафиксирован через `match: macaddress` в netplan.

---

### 1.3 Схема сети

```
                         [Internet]
                              |
                         [inetRouter] 192.168.0.130
                    ens18: 192.168.0.130/24 → gw 192.168.0.32
                    ens19: 192.168.255.1/30
                              |
                    192.168.255.2/30 (ens19)
                        [centralRouter] 192.168.0.131
        ens20        ens21       ens22       ens23            ens24
     .0.1/28      .0.33/28   .0.65/26   .255.9/30        .255.5/30
        |             |           |           |                |
  [directors]  [hw-central]  [wifi/mgt]  .255.10/30      .255.6/30
    .0.2/28                          [office1Router]  [office2Router]
  [centralServer]          ens20  ens21  ens22  ens23  ens20 ens21 ens22
                          .2.1  .2.65 .2.129 .2.193  .1.1 .1.129 .1.193
                                           |                 |
                                    .2.130 (ens19)    .1.2 (ens19)
                                    [office1Server]   [office2Server]
```

---

## Часть 2. Практика

### 2.1 Что сделано вручную на Proxmox

#### Создание Linux Bridge'ей

Файл `/etc/network/interfaces.d/vmbr`:

```
auto vmbr1
iface vmbr1 inet manual
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    # router-net

auto vmbr2
iface vmbr2 inet manual
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    # dir-net
# ... и так далее до vmbr13
```

Применено: `ifreload -a`

#### Подключение NIC к ВМ

```bash
qm set 130 --net1 virtio,bridge=vmbr1
qm set 131 --net1 virtio,bridge=vmbr1
qm set 131 --net2 virtio,bridge=vmbr2
qm set 131 --net3 virtio,bridge=vmbr3
qm set 131 --net4 virtio,bridge=vmbr4
qm set 131 --net5 virtio,bridge=vmbr5
qm set 131 --net6 virtio,bridge=vmbr6
qm set 134 --net1 virtio,bridge=vmbr2
qm set 132 --net1 virtio,bridge=vmbr5
qm set 132 --net2 virtio,bridge=vmbr7
qm set 132 --net3 virtio,bridge=vmbr8
qm set 132 --net4 virtio,bridge=vmbr9
qm set 132 --net5 virtio,bridge=vmbr10
qm set 135 --net1 virtio,bridge=vmbr9
qm set 133 --net1 virtio,bridge=vmbr6
qm set 133 --net2 virtio,bridge=vmbr11
qm set 133 --net3 virtio,bridge=vmbr12
qm set 133 --net4 virtio,bridge=vmbr13
qm set 136 --net1 virtio,bridge=vmbr11
```

---

### 2.2 Структура Ansible-проекта

```
19.network_arch/
├── hosts                        # inventory
├── provision.yml                # playbook
├── inetRouter.yaml.j2           # netplan шаблоны
├── centralRouter.yaml.j2
├── centralServer.yaml.j2
├── office1Router.yaml.j2
├── office1Server.yaml.j2
├── office2Router.yaml.j2
├── office2Server.yaml.j2
└── iptables_rules.ipv4.j2       # NAT правила
```

---

### 2.3 Запуск

```bash
# Проверить доступность
ansible -i hosts all -m ping --ask-become

# Полная настройка
ansible-playbook -i hosts provision.yml --ask-become

# Только конкретный хост
ansible-playbook -i hosts provision.yml --ask-become --limit inetRouter
```

---

### 2.4 Что делает playbook

**Play 1 — Common (все ВМ):**
- Устанавливает `traceroute`, `net-tools`
- Копирует `<hostname>.yaml.j2` → `/etc/netplan/50-cloud-init.yaml`
- Применяет `netplan apply` через handler

**Play 2 — IP forwarding (только routers):**
```
net.ipv4.conf.all.forwarding = 1
```
Без этого роутеры дропают транзитные пакеты.

**Play 3 — NAT (только inetRouter):**
- Отключает `ufw`
- Создаёт `/etc/iptables_rules.ipv4` с правилом MASQUERADE
- Создаёт systemd-сервис `iptables-restore` для персистентности после перезагрузки
- Применяет правила немедленно

**Play 4 — Reboot:**
Перезагружает все ВМ для проверки персистентности настроек.

---

### 2.5 Ключевые решения

**Статический IP на ens18** — вместо DHCP. На Ubuntu 24.04 `netplan apply`
переполучает DHCP-адрес и ВМ меняет IP, теряя SSH-соединение.

**Обратный маршрут на inetRouter** — `192.168.0.0/16 via 192.168.255.2`.
Без него inetRouter не знает куда возвращать ответы хостам лаборатории.

**Обратные маршруты на centralRouter** — на ens23 и ens24.
Без них centralRouter не знает про сети офисов и не может вернуть ответ.

**systemd вместо if-pre-up.d** — на Ubuntu 24.04 механизм `if-pre-up.d`
не работает (нет `ifupdown`). Используется systemd-сервис `iptables-restore`.

**MAC-фиксация ens24** — интерфейс net6 на centralRouter получил имя `enp2s1`
из-за PCI-слота в Proxmox. Зафиксирован через `match: macaddress` в netplan.

---

### 2.6 Проверка результата

```bash
# Интернет со всех хостов
ansible -i hosts all -m shell -a "ping -c3 8.8.8.8" --ask-become

# IP forwarding на роутерах
ansible -i hosts routers -m shell -a "sysctl net.ipv4.ip_forward" --ask-become

# Маршруты
ansible -i hosts all -m shell -a "ip route | grep default" --ask-become

# Связность между серверами
ansible -i hosts office1Server -m shell -a "ping -c3 192.168.1.2" --ask-become
ansible -i hosts office2Server -m shell -a "ping -c3 192.168.2.130" --ask-become
ansible -i hosts centralServer -m shell -a "ping -c3 192.168.2.130" --ask-become

# Traceroute с office2Server — путь через лабораторию
ansible -i hosts office2Server -m shell -a "traceroute -n 8.8.8.8" --ask-become
# 1  192.168.1.1    office2Router
# 2  192.168.255.5  centralRouter
# 3  192.168.255.1  inetRouter
# 4  192.168.0.32   провайдер
# ...
# 23 8.8.8.8

# NAT персистентен после перезагрузки
ansible -i hosts inetRouter -m shell -a "iptables-save | grep MASQUERADE" --ask-become
# -A POSTROUTING ! -d 192.168.0.0/16 -o ens18 -j MASQUERADE
```

### Итог проверки

| Условие                              | Результат |
|--------------------------------------|-----------|
| Все хосты пингуют 8.8.8.8           | ✅        |
| Трафик идёт через inetRouter         | ✅        |
| IP forwarding на всех роутерах       | ✅        |
| Серверы видят друг друга             | ✅        |
| NAT сохраняется после перезагрузки   | ✅        |
