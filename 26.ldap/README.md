# FreeIPA — Централизованная авторизация и аутентификация (LDAP)

## Описание

Развёртывание стенда FreeIPA на Proxmox VE (Rocky Linux 9.7) с интегрированным DNS (BIND).

**Задание:**
1. Установить FreeIPA-сервер
2. Написать Ansible-playbook для конфигурации клиентов
3. \* Настроить аутентификацию по SSH-ключам
4. \*\* Firewall должен быть включён на сервере и на клиенте

## Стенд

| Роль           |          FQDN         |       IP      |
|----------------|-----------------------|---------------|
| FreeIPA-сервер | ipa.qooqes.online     | 192.168.0.160 |
| Клиент 1       | client1.qooqes.online | 192.168.0.161 |
| Клиент 2       | client2.qooqes.online | 192.168.0.162 |

- **ОС сервера:** Rocky Linux 9.7
- **ОС клиентов:** Rocky Linux 9 / Debian 12 / Ubuntu 22.04+ (плейбук поддерживает все три)
- **Домен:** qooqes.online
- **Realm:** QOOQES.ONLINE
- **Шлюз:** 192.168.0.32
- **Платформа виртуализации:** Proxmox VE
- **Ресурсы на каждую ВМ:** 4 ГБ RAM, 2 vCPU, 32 ГБ диск

---

## Структура проекта

```
.
├── README.md
├── ansible/
│   ├── inventory/
│   │   └── hosts.yml
│   ├── server.yml              # Плейбук установки FreeIPA-сервера
│   ├── clients.yml             # Плейбук установки FreeIPA-клиентов
│   ├── roles/
│   │   ├── freeipa-server/
│   │   │   ├── defaults/main.yml
│   │   │   ├── tasks/main.yml
│   │   │   ├── handlers/main.yml
│   │   │   └── templates/
│   │   │       └── hosts.j2
│   │   └── freeipa-client/
│   │       ├── defaults/main.yml
│   │       ├── tasks/main.yml
│   │       ├── handlers/main.yml
│   │       └── templates/
│   │           └── hosts.j2
```

---

## Подготовка виртуальных машин в PVE

Создать 3 ВМ с Rocky Linux 9.7 (minimal install). На каждой:

- Статический IP (см. таблицу), шлюз 192.168.0.32
- Убедиться, что все 3 машины пингуют друг друга
- SSH-доступ с управляющей машины (по ключу)

---

## Установка FreeIPA-сервера (ipa.qooqes.online — 192.168.0.160)

### Базовая настройка. Установка хостейма и часового пояса

```bash
hostnamectl set-hostname ipa.qooqes.online
timedatectl set-timezone Europe/Moscow

dnf install -y chrony
systemctl enable --now chronyd
```

### Настройка /etc/hosts

```bash
nano /etc/hosts 
127.0.0.1   localhost localhost.localdomain
192.168.0.160 ipa.qooqes.online ipa
192.168.0.161 client1.qooqes.online client1
192.168.0.162 client2.qooqes.online client2
```

### SELinux переводим в permissive

```bash
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### Firewall — открываем порты для FreeIPA

```bash
firewall-cmd --permanent --add-service={freeipa-ldap,freeipa-ldaps,freeipa-replication,freeipa-trust,dns,ntp,http,https,kerberos,kpasswd,ldap,ldaps}
firewall-cmd --permanent --add-port={80/tcp,443/tcp,389/tcp,636/tcp,88/tcp,88/udp,464/tcp,464/udp,53/tcp,53/udp,123/udp}
firewall-cmd --reload
```

### Установка пакетов

```bash
dnf install -y ipa-server ipa-server-dns
```

### 2.6. Запуск установки FreeIPA

```bash
ipa-server-install \
  --setup-dns \
  --hostname=ipa.qooqes.online \
  --domain=qooqes.online \
  --realm=QOOQES.ONLINE \
  --ds-password='DirectoryPass123' \
  --admin-password='AdminPass123' \
  --ip-address=192.168.0.160 \
  --no-host-dns \
  --no-ntp \
  --forwarder=8.8.8.8 \
  --forwarder=1.1.1.1 \
  --reverse-zone=0.168.192.in-addr.arpa. \
  --allow-zone-overlap \
  --unattended
```

> **Пароли:** 
`--ds-password` — Directory Manager (полный доступ к LDAP), 
`--admin-password` — администратор FreeIPA (веб-консоль). Минимум 8 символов каждый. 

Установка заняла ~5-10 минут.

Ожидаемый результат: 

`The ipa-server-install command was successful`

###  Проверка

```bash
kinit admin
# Вводим AdminPass123
klist
ipactl status
dig ipa.qooqes.online @192.168.0.160
```

### Веб-интерфейс

На рабочей машине добавить в `/etc/hosts`:
```
192.168.0.160 ipa.qooqes.online
```
Открыть: **https://ipa.qooqes.online** (admin / AdminPass123)

---

##  Настройка клиентов (client1 — 192.168.0.161, client2 — 192.168.0.162)


### Базовая настройка

```bash
# На client1:
hostnamectl set-hostname client1.qooqes.online
# На client2:
hostnamectl set-hostname client2.qooqes.online

timedatectl set-timezone Europe/Moscow
dnf install -y chrony
systemctl enable --now chronyd
```

### прописываем адрес в /etc/hosts

```bash
nano /etc/hosts 
127.0.0.1   localhost localhost.localdomain
192.168.0.160 ipa.qooqes.online ipa
192.168.0.161 client1.qooqes.online client1
192.168.0.162 client2.qooqes.online client2

```

###  SELinux в permissive

```bash
setenforce 0
sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
```

### Firewall

```bash
firewall-cmd --permanent --add-service={freeipa-ldap,freeipa-ldaps,dns,kerberos,kpasswd}
firewall-cmd --permanent --add-port={88/tcp,88/udp,464/tcp,464/udp,389/tcp,636/tcp}
firewall-cmd --reload
```

### DNS — направить на FreeIPA-сервер

```bash
CON_NAME=$(nmcli -t -f NAME con show --active | head -1)
nmcli con mod "$CON_NAME" ipv4.dns "192.168.0.160"
nmcli con mod "$CON_NAME" ipv4.dns-search "qooqes.online"
nmcli con mod "$CON_NAME" ipv4.ignore-auto-dns yes
nmcli con up "$CON_NAME"

# Проверка
dig ipa.qooqes.online
```

### Установливаем FreeIPA-клиента

```bash
dnf install -y freeipa-client

ipa-client-install \
  --mkhomedir \
  --domain=qooqes.online \
  --realm=QOOQES.ONLINE \
  --server=ipa.qooqes.online \
  --no-ntp \
  --principal=admin \
  --password='AdminPass123' \
  --unattended
```

Ожидаемый результат: `Client configuration complete.`

### Проверка

```bash
kinit admin
klist
```

---

## Проверяем работу LDAP

### Создаем пользователя (на сервере)

```bash
kinit admin
ipa user-add otus-user --first=Otus --last=User --password
# Ввести пароль для otus-user
```

### Вход на клиенте

```bash
# На client1 или client2:
kinit otus-user
# Ввести пароль, система попросит сменить его

ssh otus-user@client1.qooqes.online
# Должна создаться домашняя директория
```

---

##  Аутентификация по SSH-ключам

### Генеррируем ключ

```bash
ssh-keygen -t ed25519 -C "otus-user@qooqes.online" -f ~/.ssh/id_ed25519
```

### Добавлеем ключ в FreeIPA

```bash
kinit admin
ipa user-mod otus-user --sshpubkey="$(cat ~/.ssh/id_ed25519.pub)"
ipa user-show otus-user --all | grep -i ssh
```

### Проверяем

```bash
ssh -i ~/.ssh/id_ed25519 otus-user@client1.qooqes.online
# Вход без пароля
```

---

## Ansible

### Запуск

```bash
cd ansible/

# Установка сервера
ansible-playbook -i inventory/hosts.yml server.yml

# Подключение клиентов
ansible-playbook -i inventory/hosts.yml clients.yml
```

Подробности — в файлах плейбуков и ролей в каталоге `ansible/`.

---

## Полезные команды

```bash
ipactl status                           # Статус FreeIPA
ipa user-find                           # Список пользователей
ipa user-show otus-user --all           # Информация о пользователе
ipa host-find                           # Хосты в домене
dig ipa.qooqes.online @192.168.0.160    # Проверка DNS
dig -x 192.168.0.160 @192.168.0.160     # Обратная DNS-запись
journalctl -u dirsrv@QOOQES-ONLINE      # Логи Directory Server
journalctl -u krb5kdc                   # Логи Kerberos
```
