SElinux

OS - rl9

[root@rocky9 ~]# sestatus

SELinux status:                 enabled
SELinuxfs mount:                /sys/fs/selinux
SELinux root directory:         /etc/selinux
Loaded policy name:             targeted
Current mode:                   enforcing
Mode from config file:          enforcing
Policy MLS status:              enabled
Policy deny_unknown status:     allowed
Memory protection checking:     actual (secure)
Max kernel policy version:      33

[root@rocky9 ~]#  systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
     Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; preset: enabled)
     Active: active (running) since Sat 2026-02-07 15:21:58 MSK; 15min ago
       Docs: man:firewalld(1)
    Process: 745 ExecStartPost=/usr/bin/firewall-cmd --state (code=exited, status=0/SUCCESS)
   Main PID: 735 (firewalld)
      Tasks: 2 (limit: 23116)
     Memory: 44.5M (peak: 65.8M)
        CPU: 1.260s
     CGroup: /system.slice/firewalld.service
             └─735 /usr/bin/python3 -s /usr/sbin/firewalld --nofork --nopid

фев 07 15:21:57 rocky9 systemd[1]: Starting firewalld - dynamic firewall daemon...
фев 07 15:21:58 rocky9 systemd[1]: Started firewalld - dynamic firewall daemon.

[root@rocky9 ]# systemctl status nginx

● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/nginx.service.d
             └─php-fpm.conf
     Active: active (running) since Sat 2026-02-07 15:21:59 MSK; 12min ago
    Process: 837 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 847 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 858 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 862 (nginx)
      Tasks: 5 (limit: 23116)
     Memory: 7.2M (peak: 8.1M)
        CPU: 107ms
     CGroup: /system.slice/nginx.service
             ├─862 "nginx: master process /usr/sbin/nginx"
             ├─863 "nginx: worker process"
             ├─864 "nginx: worker process"
             ├─865 "nginx: worker process"
             └─866 "nginx: worker process"

фев 07 15:21:59 rocky9 systemd[1]: Starting The nginx HTTP and reverse proxy server...
фев 07 15:21:59 rocky9 nginx[847]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
фев 07 15:21:59 rocky9 nginx[847]: nginx: configuration file /etc/nginx/nginx.conf test is successful
фев 07 15:21:59 rocky9 systemd[1]: Started The nginx HTTP and reverse proxy server.

[root@rocky9 lzhkn]# ss -tlpn
State         Recv-Q        Send-Q               Local Address:Port                 Peer Address:Port        Process                                                                                                      
LISTEN        0             511                        0.0.0.0:80                        0.0.0.0:*            users:(("nginx",pid=866,fd=6),("nginx",pid=865,fd=6),("nginx",pid=864,fd=6),("nginx",pid=863,fd=6),("nginx",pid=862,fd=6))
LISTEN        0             128                        0.0.0.0:22                        0.0.0.0:*            users:(("sshd",pid=811,fd=3))              




меняем порт на 92, делаем рестарт, получем ошибку:

фев 07 15:36:10 rocky9 nginx[2312]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
фев 07 15:36:10 rocky9 nginx[2312]: nginx: [emerg] bind() to 0.0.0.0:92 failed (13: Permission denied)
фев 07 15:36:10 rocky9 nginx[2312]: nginx: configuration file /etc/nginx/nginx.conf test failed
фев 07 15:36:10 rocky9 systemd[1]: nginx.service: Control process exited, code=exited, status=1/FAILURE



type=SYSCALL msg=audit(1770467770.561:350): arch=c000003e syscall=49 success=no exit=-13 a0=7 a1=562e52484890 a2=10 a3=7fff607bbdb0 items=0 ppid=1 pid=2312 auid=4294967295 uid=0 gid=0 euid=0 suid=0 fsuid=0 egid=0 sgid=0 fsgid=0 tty=(none) ses=4294967295 comm="nginx" exe="/usr/sbin/nginx" subj=system_u:system_r:httpd_t:s0 key=(null)ARCH=x86_64 SYSCALL=bind AUID="unset" UID="root" GID="root" EUID="root" SUID="root" FSUID="root" EGID="root" SGID="root" FSGID="root"
type=SERVICE_START msg=audit(1770467770.563:351): pid=1 uid=0 auid=4294967295 ses=4294967295 subj=system_u:system_r:init_t:s0 msg='unit=nginx comm="systemd" exe="/usr/lib/systemd/systemd" hostname=? addr=? terminal=? res=failed'UID="root" AUID="unset"


Добавляем в фв исключение

sudo firewall-cmd --permanent --add-port=92/tcp

Корректируем selinux под nginx

[root@rocky9 ~]# setsebool -P nis_enabled on

Смотрим порты web сервера для selinux

[root@rocky9 ~]#  semanage port -l | grep http

http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      80, 81, 443, 488, 8008, 8009, 8443, 9000


[root@rocky9 ~]#  semanage port -a -t http_port_t -p tcp 92
[root@rocky9 ~]#  semanage port -l | grep http

http_cache_port_t              tcp      8080, 8118, 8123, 10001-10010
http_cache_port_t              udp      3130
http_port_t                    tcp      92, 80, 81, 443, 488, 8008, 8009, 8443, 9000
pegasus_http_port_t            tcp      5988
pegasus_https_port_t           tcp      5989


Запускаем nginx, проверяем статус

[root@rocky9 ~]# systemctl start nginx
[root@rocky9 ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/nginx.service.d
             └─php-fpm.conf
     Active: active (running) since Sat 2026-02-07 15:54:35 MSK; 2s ago
    Process: 1935 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 1936 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 1937 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 1938 (nginx)
      Tasks: 5 (limit: 23116)
     Memory: 5.2M (peak: 5.5M)
        CPU: 56ms
     CGroup: /system.slice/nginx.service
             ├─1938 "nginx: master process /usr/sbin/nginx"
             ├─1939 "nginx: worker process"
             ├─1940 "nginx: worker process"
             ├─1941 "nginx: worker process"
             └─1942 "nginx: worker process"

фев 07 15:54:35 rocky9 systemd[1]: Starting The nginx HTTP and reverse proxy server...
фев 07 15:54:35 rocky9 nginx[1936]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
фев 07 15:54:35 rocky9 nginx[1936]: nginx: configuration file /etc/nginx/nginx.conf test is successful
фев 07 15:54:35 rocky9 systemd[1]: Started The nginx HTTP and reverse proxy server.


[root@rocky9 ~]# ss -tlpn
State                   Recv-Q                  Send-Q                                    Local Address:Port                                      Peer Address:Port                  Process                                                                                                                                                                              
LISTEN                  0                       511                                             0.0.0.0:92                                             0.0.0.0:*                      users:(("nginx",pid=1942,fd=7),("nginx",pid=1941,fd=7),("nginx",pid=1940,fd=7),("nginx",pid=1939,fd=7),("nginx",pid=1938,fd=7))                                                     

-----
Модуль
----

[root@rocky9 ~] grep nginx /var/log/audit/audit.log | audit2allow -M nginxnx
******************** ВАЖНО ***********************
Чтобы сделать этот пакет политики активным, выполните:

[root@rocky9 ~] semodule -i nginx.pp

[root@rocky9 ~]# systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; preset: disabled)
    Drop-In: /usr/lib/systemd/system/nginx.service.d
             └─php-fpm.conf
     Active: active (running) since Sat 2026-02-07 16:02:57 MSK; 1min 16s ago
    Process: 1995 ExecStartPre=/usr/bin/rm -f /run/nginx.pid (code=exited, status=0/SUCCESS)
    Process: 1998 ExecStartPre=/usr/sbin/nginx -t (code=exited, status=0/SUCCESS)
    Process: 1999 ExecStart=/usr/sbin/nginx (code=exited, status=0/SUCCESS)
   Main PID: 2000 (nginx)
      Tasks: 5 (limit: 23116)
     Memory: 5.1M (peak: 5.3M)
        CPU: 54ms
     CGroup: /system.slice/nginx.service
             ├─2000 "nginx: master process /usr/sbin/nginx"
             ├─2001 "nginx: worker process"
             ├─2002 "nginx: worker process"
             ├─2003 "nginx: worker process"
             └─2004 "nginx: worker process"

фев 07 16:02:57 rocky9 systemd[1]: Starting The nginx HTTP and reverse proxy server...
фев 07 16:02:57 rocky9 nginx[1998]: nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
фев 07 16:02:57 rocky9 nginx[1998]: nginx: configuration file /etc/nginx/nginx.conf test is successful
фев 07 16:02:57 rocky9 systemd[1]: Started The nginx HTTP and reverse proxy server.

[root@rocky9 ~]# ss -tlpn
State                   Recv-Q                  Send-Q                                    Local Address:Port                                      Peer Address:Port                  Process                                                                                                                                                                              
LISTEN                  0                       511                                             0.0.0.0:192                                            0.0.0.0:*                      users:(("nginx",pid=2004,fd=7),("nginx",pid=2003,fd=7),("nginx",pid=2002,fd=7),("nginx",pid=2001,fd=7),("nginx",pid=2000,fd=7))                                  







