# Настройка протокола OSPF в Linux (FRRouting)

**ОС:** Ubuntu 24.04 LTS  
**Демон маршрутизации:** FRRouting (FRR)  
**Пользователь:** lzhkn

---

## Окружение

| Хост | IP (mgmt)     | Роль OSPF |
|------|---------------|-----------|
| vm1  | 192.168.0.141 | Router R1 |
| vm2  | 192.168.0.142 | Router R2 |
| vm3  | 192.168.0.143 | Router R3 |

Интерфейсы на каждой VM:

| Интерфейс | Назначение              |
|-----------|-------------------------|
| ens18     | mgmt (192.168.0.x)      |
| ens19     | OSPF линк (основной)    |
| ens20     | OSPF линк (дорогой R1–R3) |

---

## Топология сети

```
              ens19            ens19
         10.0.12.0/30      10.0.23.0/30
R1 ──────────────────── R2 ──────────────────── R3
   10.0.12.1    10.0.12.2  10.0.23.1    10.0.23.2

Прямой линк R1–R3 (дорогой, cost 1000):
              ens20            ens20
         10.0.13.0/30
R1 ──────────────────────────────────────────── R3
   10.0.13.1                          10.0.13.2

Loopback (Router-ID):
  R1 lo: 1.1.1.1/32
  R2 lo: 2.2.2.2/32
  R3 lo: 3.3.3.3/32
```

---

## Структура файлов

```
22.ospf/
├── README.md
├── hosts.ini
├── ospf_playbook.yml
├── group_vars/
│   └── all.yml
├── host_vars/
│   ├── vm1.yml
│   ├── vm2.yml
│   └── vm3.yml
└── templates/
    ├── netplan.yaml.j2
    └── frr.conf.j2
```

---

## Часть 1. Установка и деплой

### Запуск плейбука

```bash
ansible-playbook -i hosts.ini ospf_playbook.yml --become --ask-become-pass
```

Плейбук выполняет:
1. Настраивает `sysctl` — включает `ip_forward`, отключает `rp_filter`
2. Деплоит Netplan-конфиг — поднимает `ens19`/`ens20` с нужными адресами и loopback
3. Подключает репозиторий FRR и устанавливает пакеты
4. Включает `ospfd` в `/etc/frr/daemons`
5. Деплоит `/etc/frr/frr.conf` из шаблона
6. Запускает и включает в автозагрузку `frr.service`

### Результат

```
PLAY RECAP
vm1 : ok=11  changed=4  unreachable=0  failed=0
vm2 : ok=11  changed=4  unreachable=0  failed=0
vm3 : ok=11  changed=4  unreachable=0  failed=0
```

---

## Часть 2. Проверка OSPF-соседства

```bash
ansible -i hosts.ini ospf_routers \
  -m command -a "vtysh -c 'show ip ospf neighbor'" \
  --become --ask-become-pass
```

```
vm1 (R1):
Neighbor ID  Pri  State        Up Time  Dead Time  Address     Interface
2.2.2.2        1  Full/DR      4.057s   15.942s    10.0.12.2   ens19:10.0.12.1
3.3.3.3        1  Full/DR      4.034s   15.965s    10.0.13.2   ens20:10.0.13.1

vm2 (R2):
Neighbor ID  Pri  State        Up Time  Dead Time  Address     Interface
1.1.1.1        1  Full/Backup  4.056s   15.925s    10.0.12.1   ens19:10.0.12.2
3.3.3.3        1  Full/DR      4.033s   15.967s    10.0.23.2   ens20:10.0.23.1

vm3 (R3):
Neighbor ID  Pri  State        Up Time  Dead Time  Address     Interface
2.2.2.2        1  Loading/Bkp  4.024s   15.953s    10.0.23.1   ens19:10.0.23.2
1.1.1.1        1  Full/Backup  4.024s   15.935s    10.0.13.1   ens20:10.0.13.2
```

Все соседи в состоянии `Full` — adjacency установлена, маршрутная база синхронизирована.

---

## Часть 3. Таблица маршрутов OSPF

```bash
ansible -i hosts.ini ospf_routers \
  -m command -a "vtysh -c 'show ip ospf route'" \
  --become --ask-become-pass
```

```
vm1 (R1):
N    1.1.1.1/32   [0]    directly attached to lo
N    2.2.2.2/32   [10]   via 10.0.12.2, ens19
N    3.3.3.3/32   [20]   via 10.0.12.2, ens19      ← через R2, не напрямую
N    10.0.12.0/30 [10]   directly attached to ens19
N    10.0.13.0/30 [1000] directly attached to ens20 ← дорогой линк
N    10.0.23.0/30 [20]   via 10.0.12.2, ens19

vm3 (R3):
N    1.1.1.1/32   [20]   via 10.0.23.1, ens19      ← через R2, не напрямую
N    2.2.2.2/32   [10]   via 10.0.23.1, ens19
N    3.3.3.3/32   [0]    directly attached to lo
N    10.0.13.0/30 [1000] directly attached to ens20 ← дорогой линк
N    10.0.23.0/30 [10]   directly attached to ens19
```

R1 и R3 оба выбирают путь через R2 — линк ens20 (R1–R3) присутствует в таблице с cost 1000, но не используется.

---

## Часть 4. Симметричный роутинг с дорогим линком

Линк R1–R3 (ens20) объявлен дорогим с **обеих сторон** — cost 1000 в `host_vars/vm1.yml` и `host_vars/vm3.yml`. Оба роутера выбирают путь через R2.

```bash
$ ssh lzhkn@192.168.0.141 "traceroute -n 3.3.3.3"
traceroute to 3.3.3.3, 30 hops max
 1  10.0.12.2  0.465 ms      ← R2
 2  3.3.3.3    0.565 ms      ← R3

$ ssh lzhkn@192.168.0.143 "traceroute -n 1.1.1.1"
traceroute to 1.1.1.1, 30 hops max
 1  10.0.23.1  0.228 ms      ← R2
 2  1.1.1.1    0.433 ms      ← R1
```

Трафик в обе стороны идёт через R2 — роутинг **симметричный**.  
Прямой линк R1–R3 остаётся живым и используется как горячий резерв: при падении R2 OSPF пересчитает маршруты автоматически.

---

## Часть 5. Асимметричный роутинг

Убираем cost на R3/ens20 — R3 начинает видеть прямой линк дешёвым и отвечает напрямую, тогда как R1 по-прежнему идёт через R2.

```bash
# Убираем cost на R3
ssh -t lzhkn@192.168.0.143 \
  "sudo vtysh -c 'conf t' -c 'interface ens20' -c 'no ip ospf cost' -c 'end' -c 'write'"
```

```bash
$ ssh lzhkn@192.168.0.141 "traceroute -n 3.3.3.3"
traceroute to 3.3.3.3, 30 hops max
 1  10.0.12.2  0.306 ms      ← R2
 2  3.3.3.3    0.368 ms      ← R3  (два хопа, через R2)

$ ssh lzhkn@192.168.0.143 "traceroute -n 1.1.1.1"
traceroute to 1.1.1.1, 30 hops max
 1  1.1.1.1    0.219 ms      ← R1  (один хоп, напрямую!)
```

Пакеты туда и обратно идут **разными путями** — это и есть асимметричный роутинг.

> **Почему это работает:** на Linux для корректного приёма асимметричного трафика обязательно отключить `rp_filter` (Reverse Path Filtering). Без этого ядро дропает пакеты, пришедшие не через best-route интерфейс. Плейбук настраивает это автоматически через `sysctl`.

### Возврат к симметрии

```bash
ssh -t lzhkn@192.168.0.143 \
  "sudo vtysh -c 'conf t' -c 'interface ens20' -c 'ip ospf cost 1000' -c 'end' -c 'write'"
```

---

## Итог

| Сценарий | R1 → R3 | R3 → R1 | Симметрия |
|----------|---------|---------|-----------|
| Базовый OSPF (все cost = 10) | напрямую или через R2 (ECMP) | напрямую или через R2 | да |
| Дорогой линк с обеих сторон (cost 1000 на R1 и R3) | через R2 | через R2 | **да** ✓ |
| Дорогой линк только на R1 (cost 1000 на R1, cost 10 на R3) | через R2 | напрямую | **нет** ✓ |

---

## Команды диагностики

```bash
# Войти в CLI FRR
sudo vtysh

# Внутри vtysh:
show ip ospf neighbor        # соседи и их состояние
show ip ospf interface       # интерфейсы с их cost
show ip ospf database        # LSDB
show ip ospf route           # маршруты OSPF
show ip route ospf           # маршруты в kernel table
exit

# Логи
sudo journalctl -u frr -f

# Проверка sysctl
sysctl net.ipv4.ip_forward
sysctl net.ipv4.conf.all.rp_filter
```
