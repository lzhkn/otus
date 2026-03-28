# Домашнее задание: PXE — автоматическая сетевая установка Ubuntu 24.04

## Задание

1. Настроить загрузку по сети дистрибутива Ubuntu 24
2. Установка должна проходить из HTTP-репозитория
3. Настроить автоматическую установку с помощью файла user-data

---

## Окружение

- **Гипервизор**: Proxmox VE / VirtualBox
- **PXE-сервер**: Ubuntu 24.04 LTS — `192.168.0.126`, интерфейс `ens18`
- **PXE-клиент**: VM в VirtualBox, загрузка по сети (Network Boot first)
- **Метод**: dnsmasq (DHCP + TFTP) + Apache2 (HTTP) + autoinstall (cloud-init)

> **Важно**: Proxmox использует iPXE вместо стандартного PXE, что требует
> дополнительной настройки. Для простой лабораторной работы рекомендуется
> использовать VirtualBox — там стандартный PXE работает без проблем.

---

## Схема работы

```
PXE-клиент включается
      ↓
DHCP (dnsmasq) → выдаёт IP (192.168.0.190-200) + адрес TFTP + pxelinux.0
      ↓
TFTP → отдаёт pxelinux.0, ldlinux.c32, pxelinux.cfg/default, linux, initrd
      ↓
HTTP (Apache) → отдаёт noble-live-server-amd64.iso (~3.2 ГБ)
      ↓
cloud-init (user-data) → автоматическая установка без мастера
```

---

## 1. Установка и базовая настройка

```bash
# Отключаем firewall
sudo systemctl stop ufw
sudo systemctl disable ufw

# Устанавливаем необходимые пакеты
sudo apt update
sudo apt install -y dnsmasq apache2 wget
```

---

## 2. Настройка DHCP и TFTP (dnsmasq)

```bash
sudo vim /etc/dnsmasq.d/pxe.conf
```

```ini
# Интерфейс для DHCP/TFTP
interface=ens18
bind-interfaces

# Отключаем DNS (порт 53 занят systemd-resolved)
port=0

# Диапазон DHCP-адресов для клиентов
dhcp-range=ens18,192.168.0.190,192.168.0.200

# Файл загрузчика для Legacy BIOS
dhcp-boot=pxelinux.0

# Файлы загрузчика для UEFI (задание со звёздочкой)
dhcp-match=set:efi-x86_64,option:client-arch,7
dhcp-boot=tag:efi-x86_64,bootx64.efi

# Включаем встроенный TFTP-сервер
enable-tftp

# Корневой каталог TFTP-сервера
tftp-root=/srv/tftp/amd64
```

```bash
sudo systemctl restart dnsmasq
sudo systemctl status dnsmasq
```

---

## 3. Скачиваем и распаковываем netboot-файлы Ubuntu 24.04

```bash
# Создаём каталог
sudo mkdir -p /srv/tftp

# Скачиваем netboot-архив Ubuntu 24.04 (Noble)
sudo wget -O /tmp/noble-netboot.tar.gz \
  https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-netboot-amd64.tar.gz

# Распаковываем в /srv/tftp
sudo tar -xzvf /tmp/noble-netboot.tar.gz -C /srv/tftp
```

После распаковки в `/srv/tftp/amd64` должна быть следующая структура:

```
/srv/tftp/amd64/
├── bootx64.efi
├── grub/
│   └── grub.cfg
├── grubx64.efi
├── initrd
├── ldlinux.c32
├── linux
├── pxelinux.0
└── pxelinux.cfg/
    └── default
```

---

## 4. Настройка Web-сервера Apache2

```bash
# Создаём каталоги
sudo mkdir /srv/images
sudo mkdir /srv/ks

# Скачиваем ISO Ubuntu 24.04 (Noble, ~3.2 ГБ)
cd /srv/images
sudo wget https://cdimage.ubuntu.com/ubuntu-server/noble/daily-live/current/noble-live-server-amd64.iso
```

Создаём конфигурацию Apache:

```bash
sudo vim /etc/apache2/sites-available/ks-server.conf
```

```apache
<VirtualHost 192.168.0.126:80>
    DocumentRoot /

    # ISO-образ Ubuntu 24.04 для сетевой установки
    <Directory /srv/images>
        Options Indexes MultiViews
        AllowOverride All
        Require all granted
    </Directory>

    # Файлы cloud-init (user-data, meta-data) для автоматической установки
    <Directory /srv/ks>
        Options Indexes MultiViews
        AllowOverride All
        Require all granted
    </Directory>
</VirtualHost>
```

```bash
# Активируем конфигурацию и перезапускаем Apache
sudo a2ensite ks-server.conf
sudo systemctl restart apache2
```

---

## 5. Настройка загрузчика PXE (pxelinux.cfg/default)

```bash
sudo vim /srv/tftp/amd64/pxelinux.cfg/default
```

```
DEFAULT install
LABEL install
  KERNEL linux
  INITRD initrd
  APPEND root=/dev/ram0 ramdisk_size=4000000 ip=dhcp iso-url=http://192.168.0.126/srv/images/noble-live-server-amd64.iso autoinstall ds=nocloud-net;s=http://192.168.0.126/srv/ks/
```

> **Важно**: строка `APPEND` должна быть **одной строкой без переносов** (`\`).
> Переносы приводят к тому, что параметры не передаются ядру и initrd
> ищет CD-ROM (`/dev/sr0`) вместо загрузки ISO по HTTP.

> `ramdisk_size=4000000` — обязательно, т.к. ISO (~3.2 ГБ) загружается в ОЗУ.

---

## 6. Файл автоматической установки (user-data)

```bash
sudo vim /srv/ks/user-data
```

```yaml
#cloud-config
autoinstall:
  version: 1

  apt:
    geoip: true
    preserve_sources_list: false
    primary:
      - arches: [amd64, i386]
        uri: http://us.archive.ubuntu.com/ubuntu
      - arches: [default]
        uri: http://ports.ubuntu.com/ubuntu-ports

  drivers:
    install: false

  identity:
    hostname: otus-linux
    # Пароль: Otus2024! (SHA-512, генерация: openssl passwd -6 'Otus2024!')
    password: "$6$sJgo6Hg5zXBwkkI8$btrEoWAb5FxKhajagWR49XM4EAOfO/Dr5bMrLOkGe3KkMYdsh7T3MU5mYwY2TIMJpVKckAwnZFs2ltUJ1abOZ."
    realname: otus
    username: otus

  kernel:
    package: linux-generic

  keyboard:
    layout: us
    toggle: null
    variant: ''

  locale: en_US.UTF-8

  network:
    ethernets:
      enp0s3:
        dhcp4: true
      enp0s8:
        dhcp4: true
    version: 2

  ssh:
    install-server: true
    allow-pw: true
    authorized-keys: []

  updates: security
```

```bash
# Создаём пустой meta-data (обязателен для cloud-init)
sudo touch /srv/ks/meta-data
```

---

## 7. Финальная перезагрузка служб и проверка

```bash
sudo systemctl restart dnsmasq
sudo systemctl restart apache2

# Проверяем порты DHCP (67) и TFTP (69)
ss -ulpn | grep -E '67|69'

# Проверяем доступность файлов по HTTP
curl -I http://192.168.0.126/srv/ks/user-data
curl -I http://192.168.0.126/srv/ks/meta-data
curl -I http://192.168.0.126/srv/images/noble-live-server-amd64.iso
```

---

## 8. Настройка PXE-клиента в VirtualBox

1. Создать новую VM
2. **RAM**: минимум 4096 МБ (ISO загружается в память)
3. **Network**: Adapter 1 → **Bridged Adapter** → выбрать физический интерфейс
4. **Boot Order**: Network первым, Hard Disk вторым
5. Запустить VM — начнётся автоматическая установка Ubuntu 24.04
6. После установки поменять Boot Order: Hard Disk первым, Network убрать

---

## 9. Мониторинг процесса установки

```bash
# Логи DHCP и TFTP в реальном времени (видно все этапы загрузки)
sudo journalctl -u dnsmasq -f

# Успешный PXE-старт выглядит так:
# DHCPDISCOVER(ens18) bc:24:11:96:7f:e4
# DHCPOFFER(ens18) 192.168.0.197 bc:24:11:96:7f:e4
# DHCPREQUEST(ens18) 192.168.0.197 bc:24:11:96:7f:e4
# DHCPACK(ens18) 192.168.0.197 bc:24:11:96:7f:e4
# sent /srv/tftp/amd64/pxelinux.0 to 192.168.0.197
# sent /srv/tftp/amd64/ldlinux.c32 to 192.168.0.197
# sent /srv/tftp/amd64/pxelinux.cfg/default to 192.168.0.197
# sent /srv/tftp/amd64/linux to 192.168.0.197
# sent /srv/tftp/amd64/initrd to 192.168.0.197

# Логи установщика на клиенте (если есть SSH-доступ)
tail -f /var/log/installer/subiquity-server-debug.log
tail -f /var/log/installer/curtin-install.log
```

---

## Структура файлов

```
/etc/dnsmasq.d/pxe.conf                    — конфиг DHCP+TFTP
/srv/tftp/amd64/                            — файлы TFTP-сервера
    pxelinux.0                              — загрузчик (BIOS)
    pxelinux.cfg/default                    — меню загрузки PXE
    linux, initrd                           — ядро и initrd Ubuntu 24
    bootx64.efi, grubx64.efi               — загрузчики (UEFI, доп. задание)
/srv/images/noble-live-server-amd64.iso    — ISO-образ Ubuntu 24.04
/srv/ks/user-data                           — файл автоматической установки
/srv/ks/meta-data                           — метаданные cloud-init (пустой)
/etc/apache2/sites-available/ks-server.conf — конфиг Apache
```

---

## Известные проблемы

**`/init: line 38: can't open /dev/sr0: No medium found`**

Initrd загрузился, но не получил параметры `iso-url` и `autoinstall`.
Причина: перенос строки `\` в файле `pxelinux.cfg/default`.
Решение: записать всю строку `APPEND` без переносов в одну строку.

---

**Proxmox VE использует iPXE вместо стандартного PXE**

iPXE встроен в BIOS виртуальной машины Proxmox и игнорирует стандартные
PXE-опции от dnsmasq. Для работы с Proxmox требуется либо настройка
iPXE-скрипта, либо использование VirtualBox для лабораторной работы.

---

**`port 53: Address already in use`**

При удалении `bind-interfaces` dnsmasq пытается занять порт 53 (DNS),
который уже занят `systemd-resolved`.
Решение: добавить `port=0` в конфиг — отключает DNS в dnsmasq.

---

## Почему dnsmasq, а не отдельные ISC-DHCP + tftpd-hpa?

`dnsmasq` совмещает DHCP и TFTP в одном процессе, что упрощает конфигурацию
и уменьшает количество движущихся частей. Для лабораторного стенда — оптимальный выбор.
