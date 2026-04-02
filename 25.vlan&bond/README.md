# Домашнее задание: Сетевые пакеты. VLAN, LACP


## Задание

В Office1 в тестовой подсети появляются серверы с дополнительными интерфейсами и адресами
в internal-сети **testLAN**:

Новые ВМ для лабаратории.

| Хост         | IP-адрес     |
|--------------|--------------|
| testClient1  | 10.10.10.254 |
| testClient2  | 10.10.10.254 |
| testServer1  | 10.10.10.1   |
| testServer2  | 10.10.10.1   |

Развести VLAN-ами:
- **testClient1 ↔ testServer1** (VLAN 100)
- **testClient2 ↔ testServer2** (VLAN 101)

Между **centralRouter** и **inetRouter** «пробросить» 2 линка (общая internal-сеть)
и объединить их в **bond** (mode=active-backup), проверить работу с отключением интерфейсов.

---

## Схема сети

### Базовая топология (из предыдущей лабораторной)

```
                         [Internet]
                              |
                         [inetRouter]  (pve-02, VMID 130)
                    ens18: 192.168.0.130/24 → gw 192.168.0.32
                    ens19: 192.168.255.1/30
                              |
                    192.168.255.2/30 (ens19)
                        [centralRouter]  (pve-02, VMID 131)
        ens20        ens21       ens22       ens23            ens24
     .0.1/28      .0.33/28   .0.65/26   .255.9/30        .255.5/30
        |             |           |           |                |
  [directors]  [hw-central]  [wifi/mgt]      |                |
    .0.2/28                          [office1Router]  [office2Router]
  [centralServer]          ens20  ens21  ens22  ens23  ens20 ens21 ens22
                          .2.1  .2.65 .2.129 .2.193  .1.1 .1.129 .1.193
                                           |                 |
                                    .2.130 (ens19)    .1.2 (ens19)
                                    [office1Server]   [office2Server]
```

### Добавленные компоненты: VLAN + Bond

```
  [inetRouter]  (pve-02)                        [centralRouter]  (pve-02)
  ens19: bond0 member ─── [vmbr1: router-net] ─── ens19: bond0 member
  ens20: bond0 member ─── [vmbr14: inet2-central]── enp2s2: bond0 member
  bond0: 192.168.255.1/30                      bond0: 192.168.255.2/30


              ┌─── vmbr15: testLAN ───┐
              │  (проброс между нодами через VLAN 3015 на nic0)  │
              │                       │
  [testClient1]  (pve-01, 138)    [testServer1]  (pve-01, 139)
  ens19.100: 10.10.10.254/24      ens19.100: 10.10.10.1/24
              │    VLAN 100           │
              │                       │
  [testClient2]  (pve-01, 144)    [testServer2]  (pve-01, 145)
  ens19.101: 10.10.10.254/24      ens19.101: 10.10.10.1/24
                   VLAN 101

  Все 4 тестовых хоста на pve-01, подключены к vmbr15.
  vmbr15 пробрасывается на pve-02 через транспортный VLAN 3015 на nic0.
  Изоляция обеспечивается тегами VLAN 100 и VLAN 101.
```

---

## Часть 1. Подготовка инфраструктуры в Proxmox

### 1.1 Кластер Proxmox — задействованы две ноды

| Нода   | IP             | Роль                                        |
|--------|----------------|---------------------------------------------|
| pve-01 | 192.168.0.101  | Тестовые ВМ (testClient1/2, testServer1/2)  |
| pve-02 | 192.168.0.102  | Лаборатория (inetRouter, centralRouter, ...) |

Обе ноды подключены к одному коммутатору через физический интерфейс `nic0`,
bridge `vmbr0` используется для mgmt-сети 192.168.0.0/24.

### 1.2 Новые ВМ Ubuntu 24.04

| VMID | Имя          | Нода   | Роль                         |
|------|-------------|--------|------------------------------|
| 138  | testClient1 | pve-01 | VLAN 100, клиент             |
| 139  | testServer1 | pve-01 | VLAN 100, сервер             |
| 144  | testClient2 | pve-01 | VLAN 101, клиент             |
| 145  | testServer2 | pve-01 | VLAN 101, сервер             |

### 1.3 Проброс L2 между нодами через транспортный VLAN

Так как тестовые ВМ живут на pve-01, а лаборатория — на pve-02, необходимо
связать bridge vmbr15 (testLAN) между нодами. Для этого используется
802.1Q VLAN-тег 3015 на физическом интерфейсе `nic0`.

> **Предварительная проверка:** коммутатор пропускает тегированные фреймы:
> ```
> # pve-01: ip link add link nic0 name nic0.3999 type vlan id 3999
> #         ip addr add 10.255.255.1/30 dev nic0.3999 && ip link set nic0.3999 up
> # pve-02: ip link add link nic0 name nic0.3999 type vlan id 3999
> #         ip addr add 10.255.255.2/30 dev nic0.3999 && ip link set nic0.3999 up
> # pve-02: ping -c 3 10.255.255.1 → OK
> # Очистка: ip link del nic0.3999 (на обеих нодах)
> ```

**На pve-02** — дописываем в `/etc/network/interfaces.d/vmbr`:

```
auto nic0.3015
iface nic0.3015 inet manual

auto vmbr15
iface vmbr15 inet manual
    bridge_ports nic0.3015
    bridge_stp off
    bridge_fd 0
    # testLAN: общая сеть для VLAN-ов
```

**На pve-01** — создаём `/etc/network/interfaces.d/lab-bridges`:

```
auto nic0.3015
iface nic0.3015 inet manual

auto vmbr15
iface vmbr15 inet manual
    bridge_ports nic0.3015
    bridge_stp off
    bridge_fd 0
    # testLAN: общая сеть для VLAN-ов
```

Применяем на обеих нодах: `ifreload -a`

### 1.4 Linux Bridge для второго линка bond (pve-02)

```
auto vmbr14
iface vmbr14 inet manual
    bridge_ports none
    bridge_stp off
    bridge_fd 0
    # inet2-central: второй линк inetRouter — centralRouter (для bond)
```

> vmbr14 используется только локально на pve-02 для второго линка bond-а
> между inetRouter и centralRouter. Пробрасывать между нодами его не нужно.

### 1.5 Подключенаем NIC к ВМ

```bash
# pve-01: тестовые ВМ — net0=vmbr0 (mgmt), net1=vmbr15 (testLAN)
qm set 138 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr15
qm set 139 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr15
qm set 144 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr15
qm set 145 --net0 virtio,bridge=vmbr0 --net1 virtio,bridge=vmbr15

# pve-02: inetRouter — добавляем второй линк через vmbr14
qm set 130 --net2 virtio,bridge=vmbr14

# pve-02: centralRouter — добавляем второй линк через vmbr14
qm set 131 --net7 virtio,bridge=vmbr14
```

### 1.6 Результирующие интерфейсы

| ВМ            | Интерфейс | Bridge | Назначение                  |
|---------------|-----------|--------|-----------------------------|
| testClient1   | ens18     | vmbr0  | mgmt (192.168.0.138)        |
|               | ens19     | vmbr15 | testLAN → VLAN 100          |
| testServer1   | ens18     | vmbr0  | mgmt (192.168.0.139)        |
|               | ens19     | vmbr15 | testLAN → VLAN 100          |
| testClient2   | ens18     | vmbr0  | mgmt (192.168.0.144)        |
|               | ens19     | vmbr15 | testLAN → VLAN 101          |
| testServer2   | ens18     | vmbr0  | mgmt (192.168.0.145)        |
|               | ens19     | vmbr15 | testLAN → VLAN 101          |
| inetRouter    | ens19     | vmbr1  | bond0 member (линк 1)       |
|               | ens20     | vmbr14 | bond0 member (линк 2)       |
| centralRouter | ens19     | vmbr1  | bond0 member (линк 1)       |
|               | enp2s2    | vmbr14 | bond0 member (линк 2)       |

---

## Часть 2. Настройка VLAN

### 2.1 Адресный план VLAN

| Хост        | Физ. интерфейс| VLAN ID | VLAN-интерфейс | IP-адрес        |
|-------------|---------------|---------|----------------|-----------------|
| testClient1 | ens19         | 100     | ens19.100      | 10.10.10.254/24 |
| testServer1 | ens19         | 100     | ens19.100      | 10.10.10.1/24   |
| testClient2 | ens19         | 101     | ens19.101      | 10.10.10.254/24 |
| testServer2 | ens19         | 101     | ens19.101      | 10.10.10.1/24   |

> Одинаковые IP-адреса (10.10.10.254 и 10.10.10.1) допустимы, т.к. хосты находятся
> в разных VLAN-ах и изолированы друг от друга на L2.

### 2.2 Netplan-конфигурация (Ubuntu 24.04)

**testClient1** (VMID 138) — `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.0.138/24]
      routes:
        - to: default
          via: 192.168.0.32
      nameservers:
        addresses: [8.8.8.8]
    ens19: {}
  vlans:
    ens19.100:
      id: 100
      link: ens19
      dhcp4: false
      addresses: [10.10.10.254/24]
```

**testServer1** (VMID 139) — `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.0.139/24]
      routes:
        - to: default
          via: 192.168.0.32
      nameservers:
        addresses: [8.8.8.8]
    ens19: {}
  vlans:
    ens19.100:
      id: 100
      link: ens19
      dhcp4: false
      addresses: [10.10.10.1/24]
```

**testClient2** (VMID 144) — `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.0.144/24]
      routes:
        - to: default
          via: 192.168.0.32
      nameservers:
        addresses: [8.8.8.8]
    ens19: {}
  vlans:
    ens19.101:
      id: 101
      link: ens19
      dhcp4: false
      addresses: [10.10.10.254/24]
```

**testServer2** (VMID 145) — `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  ethernets:
    ens18:
      addresses: [192.168.0.145/24]
      routes:
        - to: default
          via: 192.168.0.32
      nameservers:
        addresses: [8.8.8.8]
    ens19: {}
  vlans:
    ens19.101:
      id: 101
      link: ens19
      dhcp4: false
      addresses: [10.10.10.1/24]
```

### 2.3 Примененяем и проверяем VLAN

```bash
# На каждом хосте после изменения конфигураций применяем новые параметры
sudo netplan apply
```

Проверяем VLAN-интерфейса на testClient1:

```
lzhkn@testClient1:~$ ip addr show ens19.100
6: ens19.100@ens19: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether bc:24:11:e7:f8:ed brd ff:ff:ff:ff:ff:ff
    inet 10.10.10.254/24 brd 10.10.10.255 scope global ens19.100
       valid_lft forever preferred_lft forever
```

Проверяем связности VLAN 100 (testClient1 → testServer1):

```
lzhkn@testClient1:~$ ping -c 3 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=0.390 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=0.448 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.274 ms
--- 10.10.10.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2034ms
```

Проверяем связности VLAN 101 (testClient2 → testServer2):

```
lzhkn@testClient2:~$ ping -c 3 10.10.10.1
PING 10.10.10.1 (10.10.10.1) 56(84) bytes of data.
64 bytes from 10.10.10.1: icmp_seq=1 ttl=64 time=0.490 ms
64 bytes from 10.10.10.1: icmp_seq=2 ttl=64 time=0.354 ms
64 bytes from 10.10.10.1: icmp_seq=3 ttl=64 time=0.271 ms
--- 10.10.10.1 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2059ms
rtt min/avg/max/mdev = 0.271/0.371/0.490/0.090 ms
```

> **Изоляция VLAN:** testClient1 (VLAN 100) и testClient2 (VLAN 101) имеют одинаковый
> IP 10.10.10.254, но пингуют **разные** серверы — трафик изолирован тегами 802.1Q.

---

## Часть 3. Настройка Bond (Active-Backup)

### 3.1 Концепция

Между inetRouter и centralRouter — 2 линка:
- **Линк 1:** ens19 ↔ ens19 через vmbr1 (router-net) — существовал ранее
- **Линк 2:** ens20 ↔ enp2s2 через vmbr14 (inet2-central) — добавлен для bond

Оба линка объединяются в bond0 в режиме **active-backup** (mode=1):
один интерфейс активен, второй в горячем резерве. При падении активного —
мгновенное переключение без потери связности.

### 3.2 Netplan-конфигурация

**inetRouter** (VMID 130) — `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      addresses:
        - 192.168.0.130/24
      routes:
        - to: 0.0.0.0/0
          via: 192.168.0.32
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
    ens19: {}
    ens20: {}
  bonds:
    bond0:
      interfaces: [ens19, ens20]
      addresses:
        - 192.168.255.1/30
      parameters:
        mode: active-backup
        primary: ens19
        mii-monitor-interval: 100
        fail-over-mac-policy: active
      routes:
        - to: 192.168.0.0/16
          via: 192.168.255.2
```

**centralRouter** (VMID 131) — `/etc/netplan/50-cloud-init.yaml`:

```yaml
network:
  version: 2
  renderer: networkd
  ethernets:
    ens18:
      addresses:
        - 192.168.0.131/24
      nameservers:
        addresses: [8.8.8.8, 8.8.4.4]
    ens19: {}
    enp2s2: {}
    ens20:
      addresses:
        - 192.168.0.1/28
    ens21:
      addresses:
        - 192.168.0.33/28
    ens22:
      addresses:
        - 192.168.0.65/26
    ens23:
      addresses:
        - 192.168.255.9/30
      routes:
        - to: 192.168.2.0/24
          via: 192.168.255.10
    ens24:
      match:
        macaddress: bc:24:11:49:0c:67
      set-name: ens24
      addresses:
        - 192.168.255.5/30
      routes:
        - to: 192.168.1.0/24
          via: 192.168.255.6
  bonds:
    bond0:
      interfaces: [ens19, enp2s2]
      addresses:
        - 192.168.255.2/30
      parameters:
        mode: active-backup
        primary: ens19
        mii-monitor-interval: 100
        fail-over-mac-policy: active
      routes:
        - to: 0.0.0.0/0
          via: 192.168.255.1
```

### 3.3 Проверяем Bond

```
root@inetRouter:~# cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v6.8.0-107-generic
Bonding Mode: fault-tolerance (active-backup) (fail_over_mac active)
Primary Slave: ens19 (primary_reselect always)
Currently Active Slave: ens19
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0
Slave Interface: ens20
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 0
Permanent HW addr: bc:24:11:ff:bd:f7
Slave queue ID: 0
Slave Interface: ens19
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 0
Permanent HW addr: bc:24:11:cc:3e:47
Slave queue ID: 0
```

```
root@centralRouter:~# cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v6.8.0-106-generic
Bonding Mode: fault-tolerance (active-backup) (fail_over_mac active)
Primary Slave: ens19 (primary_reselect always)
Currently Active Slave: ens19
MII Status: up
MII Polling Interval (ms): 100
Up Delay (ms): 0
Down Delay (ms): 0
Peer Notification Delay (ms): 0
Slave Interface: ens19
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 0
Permanent HW addr: bc:24:11:40:0d:0e
Slave queue ID: 0
Slave Interface: enp2s2
MII Status: up
Speed: Unknown
Duplex: Unknown
Link Failure Count: 0
Permanent HW addr: bc:24:11:ec:46:00
Slave queue ID: 0
```

Связность через bond:

```
root@inetRouter:~# ping -c 3 192.168.255.2
PING 192.168.255.2 (192.168.255.2) 56(84) bytes of data.
64 bytes from 192.168.255.2: icmp_seq=1 ttl=64 time=0.070 ms
64 bytes from 192.168.255.2: icmp_seq=2 ttl=64 time=0.030 ms
64 bytes from 192.168.255.2: icmp_seq=3 ttl=64 time=0.045 ms
--- 192.168.255.2 ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2049ms
```

### 3.4 Тестируем отказоустойчивость Bond

Запускаем непрерывный ping с inetRouter → centralRouter.
На centralRouter отключаем активный интерфейс:

```
root@centralRouter:~# sudo ip link set down ens19
```

**Ping не прервался — ни одного пропущенного пакета, задержки не изменились.**

Проверка — активный slave переключился на enp2s2:

```
root@centralRouter:~# cat /proc/net/bonding/bond0 | grep -A1 "Currently Active"
Currently Active Slave: enp2s2
MII Status: up
```

Возвращаем ens19, отключаем enp2s2:

```
root@centralRouter:~# sudo ip link set up ens19
root@centralRouter:~# sudo ip link set down enp2s2
```

Ping опять не прервался. Финальное состояние bond:

```
root@centralRouter:~# cat /proc/net/bonding/bond0
Ethernet Channel Bonding Driver: v6.8.0-106-generic
Bonding Mode: fault-tolerance (active-backup) (fail_over_mac active)
Primary Slave: ens19 (primary_reselect always)
Currently Active Slave: ens19
MII Status: up
MII Polling Interval (ms): 100

Slave Interface: ens19
MII Status: up
Link Failure Count: 1
Permanent HW addr: bc:24:11:40:0d:0e

Slave Interface: enp2s2
MII Status: down
Link Failure Count: 1
Permanent HW addr: bc:24:11:ec:46:00
```

> Link Failure Count: 1 на обоих интерфейсах — каждый из них был отключён по одному разу.
> Bond корректно переключался в обе стороны без потери связности.
