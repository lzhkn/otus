# Домашнее задание: Резервное копирование — BorgBackup

## Задание

Настроить удалённый бэкап каталога `/etc` с сервера **client** при помощи **borgbackup**.

Резервные копии должны соответствовать следующим критериям:

- директория для резервных копий `/var/backup` — отдельная точка монтирования (~2 ГБ);
- репозиторий зашифрован паролем (`repokey`);
- имя бэкапа содержит дату и время снятия;
- глубина хранения — 1 год:
  - последние 3 месяца — ежедневные копии,
  - остальные месяцы — по одной копии в конце месяца;
- резервная копия снимается каждые **5 минут** (для демонстрации);
- автоматизация через **systemd timer**;
- логирование через `logger` → syslog с тегом `borg-backup`.

---

## Окружение

| Роль   | Hostname | IP             | ОС           |
|--------|----------|----------------|--------------|
| Клиент | client   | 192.168.0.110  | Ubuntu 24.04 |
| Бэкап  | backup   | 192.168.0.120  | Ubuntu 24.04 |

---

## Схема сети

```
┌─────────────────────┐          ┌──────────────────────────────┐
│       client        │   SSH    │          backup              │
│   192.168.0.110     │ ──────►  │   192.168.0.120              │
│                     │          │                              │
│  /etc  ──► borg     │          │  /var/backup  (LVM ~2 ГБ)   │
│            create   │          │  user: borg                  │
└─────────────────────┘          └──────────────────────────────┘
         systemd timer (5 min)
         логи → /var/log/syslog (тег: borg-backup)
```

---

## Настройка сервера backup

### 1. Подготовка диска под /var/backup

Диск был расширен через GUI гипервизора (+2 ГБ к существующему sda).
Свободное место оформлено как новый раздел и LVM-том:

```bash
# Смотрим таблицу разделов — видим свободное место после sda3
fdisk -l /dev/sda

# Создаём новый раздел sda4
fdisk /dev/sda
# n → 4 → Enter → Enter → w

partprobe /dev/sda

# Создаём отдельный VG и LV для бэкапа
pvcreate /dev/sda4
vgcreate vg-backup /dev/sda4
lvcreate -n lv-backup -l +100%FREE /dev/vg-backup

# Форматируем и монтируем
mkfs.ext4 /dev/vg-backup/lv-backup
mount /dev/vg-backup/lv-backup /var/backup

# Закрепляем в fstab
echo "$(blkid -s UUID -o value /dev/vg-backup/lv-backup) /var/backup ext4 defaults 0 2" >> /etc/fstab
```

### 2. Создание пользователя borg

```bash
useradd -m borg
passwd borg

# Настраиваем .ssh для приёма ключей
su - borg
mkdir -p ~/.ssh
touch ~/.ssh/authorized_keys
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit

# Передаём владение директорией бэкапов
chown borg:borg /var/backup
```

### 3. Установка borgbackup

```bash
apt install borgbackup -y
```

> Borg установлен **на обоих** серверах — и на backup, и на client.
> Без этого при `borg init` будет ошибка: `Remote: sh: 1: borg: not found`

---

## Настройка клиента

### 4. Установка borgbackup

```bash
apt install borgbackup -y
```

### 5. Генерация SSH-ключа и копирование на backup

Скрипт и systemd-сервис запускаются от **root**, поэтому ключ генерируем от root:

```bash
ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519 -N ""

# Копируем публичный ключ пользователю borg на сервер backup
ssh-copy-id -i /root/.ssh/id_ed25519.pub borg@192.168.0.120

# Проверяем — должно зайти без пароля
ssh -i /root/.ssh/id_ed25519 borg@192.168.0.120
```

### 6. Инициализация репозитория

```bash
borg init --encryption=repokey borg@192.168.0.120:/var/backup/
# Вводим и запоминаем парольную фразу
```

### 7. Тестовый запуск

```bash
export BORG_PASSPHRASE="ВАШ_ПАРОЛЬ"
export BORG_RSH="ssh -i /root/.ssh/id_ed25519"

borg create --stats --list \
  borg@192.168.0.120:/var/backup/::"etc-{now:%Y-%m-%d_%H:%M:%S}" \
  /etc

# Проверяем список архивов
borg list borg@192.168.0.120:/var/backup/
```

---

## Скрипт резервного копирования

Файл: `/usr/local/bin/borg-backup.sh`

```bash
#!/bin/bash
REPO="borg@192.168.0.120:/var/backup/"
BACKUP_TARGET="/etc"
export BORG_PASSPHRASE="ВАШ_ПАРОЛЬ"

# ВАЖНО: явно указываем ключ — systemd запускает сервис в чистом окружении
# без ~/.ssh/config, поэтому без BORG_RSH ключ не находится и
# borg пытается аутентифицироваться по паролю → Permission denied
export BORG_RSH="ssh -i /root/.ssh/id_ed25519"

# Создание архива
borg create \
  --stats \
  ${REPO}::"etc-{now:%Y-%m-%d_%H:%M:%S}" \
  ${BACKUP_TARGET} \
  2>&1 | logger -t borg-backup

# Политика очистки:
#   --keep-daily 90   — ежедневные копии за последние 3 месяца
#   --keep-monthly 12 — по одной копии в месяц за последний год
borg prune \
  --keep-daily 90 \
  --keep-monthly 12 \
  ${REPO} \
  2>&1 | logger -t borg-backup
```

```bash
chmod +x /usr/local/bin/borg-backup.sh
```

---

## Автоматизация через systemd

### Сервис `/etc/systemd/system/borg-backup.service`

```ini
[Unit]
Description=Borg Backup
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/borg-backup.sh
```

### Таймер `/etc/systemd/system/borg-backup.timer`

```ini
[Unit]
Description=Borg Backup Timer — every 5 minutes

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

### Включение и запуск

```bash
systemctl daemon-reload
systemctl enable borg-backup.timer
systemctl start borg-backup.timer

# Проверяем
systemctl list-timers | grep borg
```

---

## Проверка работы

### Логи

```bash
# Все события бэкапа
grep borg-backup /var/log/syslog

# В реальном времени
journalctl -t borg-backup -f
```

### Список архивов после 30 минут работы

```bash
export BORG_PASSPHRASE="ВАШ_ПАРОЛЬ"
export BORG_RSH="ssh -i /root/.ssh/id_ed25519"

borg list borg@192.168.0.120:/var/backup/

# etc-2026-03-27_22:38:51   Fri, 2026-03-27 22:38:59 [b6ae1b1...]
# etc-2026-03-27_22:43:52   Fri, 2026-03-27 22:43:58 [c91f3d2...]
# etc-2026-03-27_22:48:53   Fri, 2026-03-27 22:48:59 [d04a5e3...]
# ...
```

---

## Процесс восстановления

```bash
export BORG_PASSPHRASE="ВАШ_ПАРОЛЬ"
export BORG_RSH="ssh -i /root/.ssh/id_ed25519"

# 1. Смотрим доступные архивы
borg list borg@192.168.0.120:/var/backup/

# 2. Восстанавливаем /etc из последнего архива
cd /
ARCHIVE=$(borg list borg@192.168.0.120:/var/backup/ --short | tail -1)
borg extract borg@192.168.0.120:/var/backup/::${ARCHIVE} etc

# 3. Восстановить отдельный файл
borg extract borg@192.168.0.120:/var/backup/::${ARCHIVE} etc/hostname

# 4. Проверяем
ls /etc | head -20
```

