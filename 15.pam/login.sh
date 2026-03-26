#!/bin/bash
# /usr/local/bin/login.sh
#
# PAM-скрипт: запрещает вход в выходные дни (Сб, Вс)
# всем пользователям, кроме членов группы admin.
#
# Используется через модуль pam_exec в /etc/pam.d/sshd
# Переменная PAM_USER автоматически передаётся модулем pam_exec.

# Если сегодня суббота или воскресенье — проверяем группу
if [ "$(date +%a)" = "Sat" ] || [ "$(date +%a)" = "Sun" ]; then

    # Пользователь входит в группу admin — разрешаем
    if getent group admin | grep -qw "$PAM_USER"; then
        exit 0
    fi

    # Иначе — запрещаем
    echo "Access denied: weekend login is restricted to admin group members." >&2
    exit 1

fi

# Будний день — разрешаем всем
exit 0
