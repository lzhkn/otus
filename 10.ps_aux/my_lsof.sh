#!/bin/bash
printf "%-8s %-6s %-8s %s\n" PID FD TYPE TARGET

# Перебор процессов
for proc in /proc/[0-9]*; do
    pid=${proc##*/}

    # Каталог fd содержит файловые дескрипторы
    [[ -d /proc/$pid/fd ]] || continue

    for fd in /proc/$pid/fd/*; do
        fdnum=${fd##*/}

        # readlink показывает, на что указывает fd
        target=$(readlink "$fd" 2>/dev/null) || continue

        # Определяем тип
        if [[ "$target" =~ socket ]]; then
            type="SOCKET"
        elif [[ "$target" =~ pipe ]]; then
            type="PIPE"
        elif [[ "$target" =~ anon_inode ]]; then
            type="ANON"
        else
            type="FILE"
        fi

        printf "%-8s %-6s %-8s %s\n" "$pid" "$fdnum" "$type" "$target"
    done
done
