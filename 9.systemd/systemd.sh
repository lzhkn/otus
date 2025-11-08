systemd.sh

Пишем service, который будет раз в 30 секунд мониторить лог на предмет наличия ключевого слова

1. Создаем конфигурационный файл /etc/default/watchlog

Он хранит переменные окружения — путь к логу и ключевое слово для поиска.

root@ubuntu2402:~# nano /etc/default/watchlog

# Configuration file for my watchlog service
# Place it to /etc/default
# File and word in that file that we will be monitor

WORD="ALERT"
LOG=/var/log/watchlog.log

systemd через директиву EnvironmentFile подставляет эти значения в переменные при запуске сервиса.

1.2 Создаем лог-файл и добавлем тестовые данные

# Создаем лог-файл
sudo touch /var/log/watchlog.log

# Добавляем тестовые данные с ключевым словом
echo "Normal log entry" | sudo tee -a /var/log/watchlog.log
echo "Important ALERT message" | sudo tee -a /var/log/watchlog.log
echo "Another normal entry" | sudo tee -a /var/log/watchlog.log


1.3 Создаем скрипта мониторинга

# Создаем скрипт
root@ubuntu2402:~# nano /opt/watchlog.sh
#!/bin/bash

WORD=$1
LOG=$2
DATE=$(date)

if grep "$WORD" "$LOG" &> /dev/null; then
    logger "$DATE: I found word, Master!"
else
    exit 0
fi

root@ubuntu2402:~# chmod +x /opt/watchlog.sh

Команда logger отправляет текст в системный журнал (/var/log/syslog или /var/log/messages)

1.4 Создание unit-файла для сервиса

root@ubuntu2402:~# nano /etc/systemd/system/watchlog.service

[Unit]
Description=My watchlog service

[Service]
Type=oneshot
EnvironmentFile=/etc/default/watchlog
ExecStart=/opt/watchlog.sh $WORD $LOG
User=root

1.5 Создание unit-файла для таймера

root@ubuntu2402:~# nano /etc/systemd/system/watchlog.timer

[Unit]
Description=Run watchlog script every 30 second

[Timer]
# Run every 30 second
OnUnitActiveSec=30
OnBootSec=30
Unit=watchlog.service

[Install]
WantedBy=multi-user.target

1.6 Запуск и проверка сервиса

# Перезагружаем демон systemd
root@ubuntu2402:~# systemctl daemon-reload

# Включаем автозагрузку таймера
root@ubuntu2402:~# systemctl enable watchlog.timer

# Запускаем таймер
root@ubuntu2402:~# systemctl start watchlog.timer

# Проверяем статус таймера
root@ubuntu2402:~# systemctl status watchlog.timer
● watchlog.timer - Run watchlog script every 30 second
     Loaded: loaded (/etc/systemd/system/watchlog.timer; enabled; preset: enabled)
     Active: active (waiting) since Sat 2025-11-08 21:26:10 MSK; 23min ago
    Trigger: Sat 2025-11-08 21:50:31 MSK; 21s left
   Triggers: ● watchlog.service

Nov 08 21:26:10 ubuntu2402 systemd[1]: Started watchlog.timer - Run watchlog script every 30 second.


# Проверяем работу сервиса

root@ubuntu2402:~# tail -n 1000 /var/log/syslog  | grep word
2025-11-08T21:26:10.042453+03:00 ubuntu2402 root: Sat Nov  8 09:26:10 PM MSK 2025: I found word, Master!
2025-11-08T21:27:01.612973+03:00 ubuntu2402 root: Sat Nov  8 09:27:01 PM MSK 2025: I found word, Master!
2025-11-08T21:27:47.703994+03:00 ubuntu2402 root: Sat Nov  8 09:27:47 PM MSK 2025: I found word, Master!
2025-11-08T21:28:32.104036+03:00 ubuntu2402 root: Sat Nov  8 09:28:32 PM MSK 2025: I found word, Master!
2025-11-08T21:29:04.365253+03:00 ubuntu2402 root: Sat Nov  8 09:29:04 PM MSK 2025: I found word, Master!
2025-11-08T21:29:36.749984+03:00 ubuntu2402 root: Sat Nov  8 09:29:36 PM MSK 2025: I found word, Master!
2025-11-08T21:30:11.625791+03:00 ubuntu2402 root: Sat Nov  8 09:30:11 PM MSK 2025: I found word, Master!
2025-11-08T21:31:11.630419+03:00 ubuntu2402 root: Sat Nov  8 09:31:11 PM MSK 2025: I found word, Master!
2025-11-08T21:31:52.868888+03:00 ubuntu2402 root: Sat Nov  8 09:31:52 PM MSK 2025: I found word, Master!
2025-11-08T21:32:31.618342+03:00 ubuntu2402 root: Sat Nov  8 09:32:31 PM MSK 2025: I found word, Master!
2025-11-08T21:33:02.298159+03:00 ubuntu2402 root: Sat Nov  8 09:33:02 PM MSK 2025: I found word, Master!
2025-11-08T21:33:33.869961+03:00 ubuntu2402 root: Sat Nov  8 09:33:33 PM MSK 2025: I found word, Master!


Установить spawn-fcgi и создать unit-файл (spawn-fcgi.sevice) с помощью переделки init-скрипта

2. Установка spawn-fcgi и создание unit-файла
2.1 Установка необходимых пакетов

# Обновляем список пакетов
root@ubuntu2402:~# apt update

# Устанавливаем spawn-fcgi и необходимые компоненты
root@ubuntu2402:~# apt install spawn-fcgi php php-cgi php-cli apache2 libapache2-mod-fcgid -y


2.2 Создание конфигурационного файла для spawn-fcgi

# Создаем директорию для конфигурации
root@ubuntu2402:~#  mkdir -p /etc/spawn-fcgi

# Создаем конфигурационный файл
root@ubuntu2402:~#  nano /etc/spawn-fcgi/fcgi.conf

# You must set some working options before the "spawn-fcgi" service will work.
# If SOCKET points to a file, then this file is cleaned up by the init script.
#
# See spawn-fcgi(1) for all possible options.
#
# Example :
SOCKET=/var/run/php-fcgi.sock
OPTIONS="-u www-data -g www-data -s $SOCKET -S -M 0600 -C 32 -F 1 -- /usr/bin/php-cgi"

2.3 Создание unit-файла для spawn-fcgi

root@ubuntu2402:~# nano /etc/systemd/system/spawn-fcgi.service
[Unit]
Description=Spawn-fcgi startup service by Otus
After=network.target

[Service]
Type=simple
PIDFile=/var/run/spawn-fcgi.pid
EnvironmentFile=/etc/spawn-fcgi/fcgi.conf
ExecStart=/usr/bin/spawn-fcgi -n $OPTIONS
KillMode=process
Restart=on-failure

[Install]
WantedBy=multi-user.target


2.4 Запуск и проверка spawn-fcgi

# Перезагружаем демон systemd
root@ubuntu2402:~#  systemctl daemon-reload

# Включаем автозагрузку
root@ubuntu2402:~#  systemctl enable spawn-fcgi.service

# Запускаем сервис
root@ubuntu2402:~#  systemctl start spawn-fcgi.service

# Проверяем статус
root@ubuntu2402:~# systemctl status spawn-fcgi.service
● spawn-fcgi.service - Spawn-fcgi startup service by Otus
     Loaded: loaded (/etc/systemd/system/spawn-fcgi.service; enabled; preset: enabled)
     Active: active (running) since Sat 2025-11-08 21:29:47 MSK; 10s ago
   Main PID: 25561 (php-cgi)
      Tasks: 33 (limit: 4602)
     Memory: 14.6M (peak: 14.9M)
        CPU: 56ms
     CGroup: /system.slice/spawn-fcgi.service
             ├─25561 /usr/bin/php-cgi
             ├─25566 /usr/bin/php-cgi
             ├─25567 /usr/bin/php-cgi
             ├─25568 /usr/bin/php-cgi
             ├─25569 /usr/bin/php-cgi
             ├─25570 /usr/bin/php-cgi
             ├─25571 /usr/bin/php-cgi
             ├─25572 /usr/bin/php-cgi
             ├─25573 /usr/bin/php-cgi
             ├─25574 /usr/bin/php-cgi
             ├─25575 /usr/bin/php-cgi
             ├─25576 /usr/bin/php-cgi
             ├─25577 /usr/bin/php-cgi
             ├─25578 /usr/bin/php-cgi
             ├─25580 /usr/bin/php-cgi
             ├─25581 /usr/bin/php-cgi
             ├─25582 /usr/bin/php-cgi
             ├─25583 /usr/bin/php-cgi
             ├─25584 /usr/bin/php-cgi
             ├─25585 /usr/bin/php-cgi
             ├─25586 /usr/bin/php-cgi
             ├─25587 /usr/bin/php-cgi
             ├─25588 /usr/bin/php-cgi
             ├─25589 /usr/bin/php-cgi
             ├─25590 /usr/bin/php-cgi
             ├─25591 /usr/bin/php-cgi
             ├─25592 /usr/bin/php-cgi
             ├─25593 /usr/bin/php-cgi


3. Доработка unit-файла Nginx для запуска нескольких экземпляров Nginx (инстансный unit)
3.1 Установка Nginx

root@ubuntu2402:~# apt install nginx -y


root@ubuntu2402:~# nano /etc/systemd/system/nginx@.service




Понять, как создавать инстансные (template) unit-файлы, чтобы запускать несколько копий одного сервиса с разными конфигами.

1. Установливаем Nginx

root@ubuntu2402:~# apt install nginx -y

2. Создаем шаблонный unit /etc/systemd/system/nginx@.service

root@ubuntu2402:~# nano /etc/systemd/system/nginx@.service

[Unit]
Description=A high performance web server and a reverse proxy server
Documentation=man:nginx(8)
After=network.target nss-lookup.target

[Service]
Type=forking
PIDFile=/run/nginx-%I.pid
ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-%I.conf -q -g 'daemon on; master_process on;'
ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;'
ExecReload=/usr/sbin/nginx -c /etc/nginx/nginx-%I.conf -g 'daemon on; master_process on;' -s reload
ExecStop=-/sbin/start-stop-daemon --quiet --stop --retry QUIT/5 --pidfile /run/nginx-%I.pid
TimeoutStopSec=5
KillMode=mixed

[Install]
WantedBy=multi-user.target

3.3 Создание конфигурационных файлов для разных инстансов
Создаем первую конфигурацию:

root@ubuntu2402:~# cp /etc/nginx/nginx.conf /etc/nginx/nginx-first.conf
root@ubuntu2402:~# nano /etc/nginx/nginx-first.conf

Находим и изменяем строку с pid:

pid /run/nginx-first.pid;

В секции http добавляем/изменяем server блок:

nginx
http {
    # ... существующие настройки ...
    
    server {
        listen 9001;
        server_name localhost;
        
        location / {
            return 200 "First Nginx instance on port 9001\n";
            add_header Content-Type text/plain;
        }
    }
    
    # Закомментируем или удалим include для sites-enabled
    # include /etc/nginx/sites-enabled/*;
}



Создаем вторую конфигурацию:


root@ubuntu2402:~# cp /etc/nginx/nginx.conf /etc/nginx/nginx-second.conf
root@ubuntu2402:~# nano /etc/nginx/nginx-second.conf

Находим и изменяем строку с pid:

pid /run/nginx-second.pid;

В секции http добавляем/изменяем server блок:

nginx
http {
    # ... существующие настройки ...
    
    server {
        listen 9002;
        server_name localhost;
        
        location / {
            return 200 "Second Nginx instance on port 9002\n";
            add_header Content-Type text/plain;
        }
    }
    
    # Закомментируем или удалим include для sites-enabled
    # include /etc/nginx/sites-enabled/*;
}


3.4 Запускаем и проверяем


root@ubuntu2402:~# systemctl daemon-reload

root@ubuntu2402:~# systemctl status nginx@first
● nginx@first.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Sat 2025-11-08 21:41:31 MSK; 9s ago
       Docs: man:nginx(8)
    Process: 26405 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-first.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 26410 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 26411 (nginx)
      Tasks: 5 (limit: 4602)
     Memory: 3.7M (peak: 4.2M)
        CPU: 33ms
     CGroup: /system.slice/system-nginx.slice/nginx@first.service
             ├─26411 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-first.conf -g daemon on; master_process on;"
             ├─26412 "nginx: worker process"
             ├─26413 "nginx: worker process"
             ├─26414 "nginx: worker process"
             └─26415 "nginx: worker process"

Nov 08 21:41:31 ubuntu2402 systemd[1]: Starting nginx@first.service - A high performance web server and a reverse proxy server...
Nov 08 21:41:31 ubuntu2402 systemd[1]: Started nginx@first.service - A high performance web server and a reverse proxy server.

root@ubuntu2402:~# systemctl status nginx@second.service 
● nginx@second.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/etc/systemd/system/nginx@.service; disabled; preset: enabled)
     Active: active (running) since Sat 2025-11-08 21:41:25 MSK; 23s ago
       Docs: man:nginx(8)
    Process: 26391 ExecStartPre=/usr/sbin/nginx -t -c /etc/nginx/nginx-second.conf -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 26393 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 26394 (nginx)
      Tasks: 5 (limit: 4602)
     Memory: 3.7M (peak: 3.9M)
        CPU: 24ms
     CGroup: /system.slice/system-nginx.slice/nginx@second.service
             ├─26394 "nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx-second.conf -g daemon on; master_process on;"
             ├─26395 "nginx: worker process"
             ├─26396 "nginx: worker process"
             ├─26397 "nginx: worker process"
             └─26398 "nginx: worker process"

Nov 08 21:41:25 ubuntu2402  systemd[1]: Starting nginx@second.service - A high performance web server and a reverse proxy server...
Nov 08 21:41:25 ubuntu2402  systemd[1]: Started nginx@second.service - A high performance web server and a reverse proxy server.
root@ubuntu2402:~# 



