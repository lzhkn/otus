## Окружение

 web   - zabbix   - 192.168.0.202 - Rocky Linux 9  - nginx + rsyslog-клиент + auditd 
 log   - gitlab   - 192.168.0.11  - Ubuntu 24.04   - Центральный сервер rsyslog      

---


### Машина log (Ubuntu 24.04)

Редактируем `/etc/rsyslog.conf` — раскомментируем модули и добавляем в конец:

```bash
nano /etc/rsyslog.conf
```

Раскомментируем:

```
module(load="imudp")
input(type="imudp" port="514")

module(load="imtcp")
input(type="imtcp" port="514" address="0.0.0.0")
```

В конец файла дописываем:

```bash
nano /etc/rsyslog.conf

$template RemoteLogs,"/var/log/rsyslog/%HOSTNAME%/%PROGRAMNAME%.log"
if $fromhost-ip != '127.0.0.1' then ?RemoteLogs
& stop

```

Создаём директорию с правильными правами:

```bash
mkdir -p /var/log/rsyslog
chown -R syslog:adm /var/log/rsyslog
chmod 755 /var/log/rsyslog
```

Открываем порт и перезапускаем:

```bash
ufw allow 514/tcp
ufw allow 514/udp
systemctl restart rsyslog
```

Проверяем — TCP должен слушать на `0.0.0.0:514`:

```bash
ss -tulpn | grep 514
```

---

### Машина web (Rocky Linux 9)

Устанавливаем пакеты:

```bash
dnf install -y nginx audispd-plugins
systemctl enable --now nginx
firewall-cmd --permanent --add-service=http
firewall-cmd --reload
```

Разрешаем SELinux:

```bash
setsebool -P httpd_can_network_connect 1
```

Редактируем `/etc/nginx/nginx.conf` — в блоке `http {}`:

```nginx
# access_log — локально И на удалённый сервер
access_log /var/log/nginx/access.log main;
access_log syslog:server=192.168.0.11:514,tag=nginx_access,severity=info combined;

# error_log — локально И на удалённый сервер
error_log /var/log/nginx/error.log warn;
error_log syslog:server=192.168.0.11:514,tag=nginx_error warn;
```

Если есть виртуальные хосты в `conf.d/` — добавляем логи в каждый `server {}`:

```nginx
server {
    access_log /var/log/nginx/access.log main;
    access_log syslog:server=192.168.0.11:514,tag=nginx_access,severity=info combined;
    error_log  syslog:server=192.168.0.11:514,tag=nginx_error warn;
    ...
}
```

```bash
nginx -t && systemctl restart nginx
```

Настраиваем rsyslog-клиент:

```bash
nano /etc/rsyslog.d/50-remote.conf
*.crit @@192.168.0.11:514

if $syslogfacility-text == 'local6' then @@192.168.0.11:514
if $syslogfacility-text == 'local6' then stop

--
systemctl restart rsyslog
```

Настраиваем auditd:

```bash
nano /etc/audit/rules.d/nginx.rules 
-w /etc/nginx/nginx.conf -p wa -k nginx_conf
-w /etc/nginx/conf.d/ -p wa -k nginx_conf

augenrules --load
```

```bash
nano /etc/audit/plugins.d/syslog.conf 
active = yes
direction = out
path = builtin_syslog
type = always
args = LOG_LOCAL6
format = string

service auditd restart
```

---

## Проверка

```bash
# На web — генерируем все типы логов:
curl http://192.168.0.202/
curl http://192.168.0.202/
logger -p crit "test crit"
echo "# test" >> /etc/nginx/nginx.conf && sed -i '/# test/d' /etc/nginx/nginx.conf
```

```bash
# На log — смотрим результат:
find /var/log/rsyslog/ -type f
tail -3 /var/log/rsyslog/zabbix/nginx_access.log
tail -3 /var/log/rsyslog/zabbix/nginx_error.log
tail -3 /var/log/rsyslog/zabbix/root.log
```
