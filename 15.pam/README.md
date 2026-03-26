# Домашнее задание: PAM — ограничение входа в выходные дни

## Задание

Ограничить доступ к системе для всех пользователей, **кроме группы `admin`**,
в выходные дни (суббота и воскресенье).

---

## Окружение

- ОС: Ubuntu 24.04 LTS (Noble Numbat)
- Метод: PAM модуль `pam_exec` + bash-скрипт

---

### Создаем пользователей и группы

```bash
# Создаём двух тестовых пользователей
sudo useradd -m -s /bin/bash otus
sudo useradd -m -s /bin/bash otusadm

# Устанавливаем пароли через chpasswd
# (флаг --stdin у passwd удалён в Ubuntu 24.04)
echo "otus:Otus2024!"    | sudo chpasswd
echo "otusadm:Otus2024!" | sudo chpasswd

# Создаём группу admin
sudo groupadd -f admin

# Добавляем в группу admin: root, otusadm и текущего пользователя
# otus намеренно НЕ добавляем — он будет заблокирован в выходные
sudo usermod -aG admin root
sudo usermod -aG admin otusadm
sudo usermod -aG admin "$USER"
```

Проверяем состав группы:
```bash
grep admin /etc/group

```

---

### Создаем скрипт login.sh


sudo vim /usr/local/bin/login.sh


Содержимое скрипта:

```bash
#!/bin/bash
# Запрещает вход в выходные дни всем, кроме группы admin.
# Переменная PAM_USER передаётся автоматически модулем pam_exec.

if [ "$(date +%a)" = "Sat" ] || [ "$(date +%a)" = "Sun" ]; then
    if getent group admin | grep -qw "$PAM_USER"; then
        exit 0   # пользователь в группе admin — разрешаем
    fi
    echo "Access denied: weekend login restricted to admin group." >&2
    exit 1       # не в группе admin — запрещаем
fi

exit 0           # будний день — разрешаем всем
```

Делаем скрипт исполняемым:
```bash
sudo chmod +x /usr/local/bin/login.sh
```

---

### Подключение скрипта в PAM

```bash
# Делаем резервную копию!
sudo cp /etc/pam.d/sshd /etc/pam.d/sshd.bak

sudo vim /etc/pam.d/sshd
```

Добавляем строку **сразу после `@include common-auth`**:

```
auth required pam_exec.so debug /usr/local/bin/login.sh
```

Итоговый вид начала файла:
```
#%PAM-1.0
@include common-auth

# Ограничение по выходным через внешний скрипт
auth required pam_exec.so debug /usr/local/bin/login.sh

account    required     pam_nologin.so
...
```

> **Флаг `debug`** пишет вывод скрипта в `/var/log/auth.log`.
> После проверки работы можно убрать.

---

### Проверка

Симулируем выходной день вручную

Используем дату 29 марта 2026 (воскресенье):

```bash
# Устанавливаем воскресенье 29 марта 2026
sudo date 032912002026.00

# Проверяем
date
# → Sun Mar 29 12:00:00 UTC 2026

date +%a
# → Sun

# Пробуем войти от обоих пользователей
ssh otus@127.0.0.1      # Permission denied (access denied)
ssh otusadm@127.0.0.1   # успешно

# Возвращаем реальное время через NTP
sudo systemctl restart systemd-timesyncd
```

#### Проверка логов

```bash
sudo tail -f /var/log/auth.log

# При отказе увидим строки вида:
# pam_exec(sshd:auth): /usr/local/bin/login.sh failed: exit code 1
# pam_exec(sshd:auth): stdout: Access denied: weekend login restricted to admin group.
```

---

## Логика работы скрипта

```
Сегодня суббота или воскресенье?  (date +%a = Sat / Sun)
        │
       ДА ──→ PAM_USER входит в группу admin?  (getent group admin)
        │              │
        │             ДА ──→ exit 0  (разрешено)
        │              │
        │             НЕТ ──→ exit 1  (запрещено)
        │
       НЕТ ──→ exit 0  (будний день — разрешено всем)
```

---

## Почему pam_exec, а не pam_time?

Модуль `pam_time` работает с отдельными пользователями или netgroups,
но **не умеет работать с локальными группами Linux** (`/etc/group`).
Это потребовало бы перечислять каждого пользователя-исключения вручную.

`pam_exec` + bash-скрипт позволяет использовать `getent group admin`,
что элегантно решает задачу для произвольного числа пользователей в группе.

---

## Структура файлов

```
/usr/local/bin/login.sh     — скрипт проверки
/etc/pam.d/sshd             — конфиг PAM для SSH (с нашей строкой)
/etc/pam.d/sshd.bak         — резервная копия оригинала
/var/log/auth.log           — логи аутентификации
```


