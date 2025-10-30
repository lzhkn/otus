Установливаем сервер NFS:

root@ubuntu2402:~# apt install nfs-kernel-server -y

Проверяем порты:

root@ubuntu2402:~# ss -tlpn

State             Recv-Q            Send-Q                       Local Address:Port                          Peer Address:Port            Process                                                            
LISTEN            0                 64                                 0.0.0.0:2049                               0.0.0.0:*                                                                                  
LISTEN            0                 4096                               0.0.0.0:111                                0.0.0.0:*                users:(("rpcbind",pid=15478,fd=4),("systemd",pid=1,fd=189))      

Создаём и настраиваем директорию, которая будет экспортирована в будущем 

root@ubuntu2402:~# mkdir -p /srv/share/upload 
root@ubuntu2402:~# chown -R nobody:nogroup /srv/share 
root@ubuntu2402:~# chmod 0777 /srv/share/upload 



Cоздаём в файле /etc/exports структуру, которая позволит экспортировать ранее созданную директорию:

root@ubuntu2402:~# cat << EOF > /etc/exports 
/srv/share 192.168.1.169/32(rw,sync,root_squash)
EOF

Проверяем:


root@ubuntu2402:~# exportfs -r 
exportfs: /etc/exports [1]: Neither 'subtree_check' or 'no_subtree_check' specified for export "192.168.1.160/32:/srv/share".
  Assuming default behaviour ('no_subtree_check').
  NOTE: this default has changed since nfs-utils version 1.0.x

root@ubuntu2402:~# exportfs -s 
/srv/share  192.168.1.169/32(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)


Настраиваем клиент NFS 

root@ws:~# apt install nfs-common

Добавляем в /etc/fstab строку 

 echo "192.168.1.160:/srv/share/ /mnt nfs vers=3,noauto,x-systemd.automount 0 0" >> /etc/fstab

root@ws:~# systemctl daemon-reload 

root@ws:~# systemctl restart remote-fs.target 

root@ws:~# mount | grep mnt 
systemd-1 on /mnt type autofs (rw,relatime,fd=90,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=1953418)

Проверяем создаем файл на сервере 

root@ubuntu2402:~# cd /srv/share/upload/
root@ubuntu2402:/srv/share/upload# touch check_file
root@ubuntu2402:/srv/share/upload# ll
total 7
drwxrwxrwx 2 nobody nogroup 4096 Oct 30 16:54 ./
drwxr-xr-x 3 nobody nogroup 4096 Oct 30 16:50 ../
-rw-r--r-- 1 root   root       0 Oct 30 16:53 check_file

root@ws:# cd /mnt/upload/
root@ws:/mnt/upload# touch client_file
root@ws:/mnt/upload# ll
итого 8
drwxrwxrwx 2 nobody nogroup 4096 окт 30 16:54 ./
drwxr-xr-x 3 nobody nogroup 4096 окт 30 16:50 ../
-rw-r--r-- 1 root   root       0 окт 30 16:53 check_file
-rw-r--r-- 1 nobody nogroup    0 окт 30 16:54 client_file

проверяем RDC на клиенте
 
root@ws:/mnt/upload# showmount -a 192.168.1.160
All mount points on 192.168.1.160:
192.168.1.169:/srv/share

root@ws:/mnt/upload# showmount -a 192.168.1.160
All mount points on 192.168.1.160:
192.168.1.169:/srv/share

root@ws:/mnt/upload#  mount | grep mnt

systemd-1 on /mnt type autofs (rw,relatime,fd=90,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=1953418)
192.168.1.160:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=524288,wsize=524288,namlen=255,hard,fatal_neterrors=none,proto=tcp,timeo=600,retrans=2,sec=sys,mountaddr=192.168.1.160,mountvers=3,mountport=39816,mountproto=udp,local_lock=none,addr=192.168.1.160)

root@ws:/mnt/upload# touch final_check

на сервере

root@ubuntu2402:/srv/share/upload# showmount -a 192.168.1.160
All mount points on 192.168.1.160:
192.168.1.169:/srv/share

root@ubuntu2402:/srv/share/upload# ll
total 8
drwxrwxrwx 2 nobody nogroup 4096 Oct 30 17:03 ./
drwxr-xr-x 3 nobody nogroup 4096 Oct 30 16:50 ../
-rw-r--r-- 1 root   root       0 Oct 30 16:53 check_file
-rw-r--r-- 1 nobody nogroup    0 Oct 30 16:54 client_file
-rw-r--r-- 1 nobody nogroup    0 Oct 30 17:03 final_check