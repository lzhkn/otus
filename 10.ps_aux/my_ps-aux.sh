#!/booin/bash
# Выводим заголовок таблицы
printf "%-8s %-6s %-6s %s\n" PID TTY STAT CMD

# Перебираем все каталоги /proc/<PID>
for proc in /proc/[0-9]*; do
    pid=${proc##*/}

    # Проверяем, что можем читать stat
    [[ -r /proc/$pid/stat ]] || continue

    # /proc/<pid>/stat — основной файл с состоянием процесса
    stat=$(cat /proc/$pid/stat)

    # Поле 3 — состояние процесса (R,S,D,Z,T…)
    state=$(awk '{print $3}' <<< "$stat")

    # Поле 7 — номер tty (0 = нет терминала)
    tty_nr=$(awk '{print $7}' <<< "$stat")

    if [[ "$tty_nr" -eq 0 ]]; then
        tty="?"
    else
        tty="tty$tty_nr"
    fi

    # cmdline — команда запуска, разделена \0
    cmd=$(tr '\0' ' ' < /proc/$pid/cmdline)

    # Если cmdline пустой — это kernel thread
    if [[ -z "$cmd" ]]; then
        cmd="[$(awk '{print $2}' <<< "$stat")]"
    fi

    printf "%-8s %-6s %-6s %s\n" "$pid" "$tty" "$state" "$cmd"
done
