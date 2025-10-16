Raid10

###смотрим что у нас по дискам

[root@ubuntu2402]:~#  lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda               8:0    0   50G  0 disk 
├─sda1            8:1    0    1M  0 part 
├─sda2            8:2    0    2G  0 part /boot
└─sda3            8:3    0   48G  0 part 
  ├─system-root 252:0    0   10G  0 lvm  /
  ├─system-home 252:1    0   10G  0 lvm  /home
  ├─system-var  252:2    0   10G  0 lvm  /var
  ├─system-log  252:3    0   10G  0 lvm  /var/log
  ├─system-swap 252:4    0    3G  0 lvm  [SWAP]
  └─system-tmp  252:5    0    5G  0 lvm  /tmp
sdb               8:16   0    5G  0 disk 
sdc               8:32   0    5G  0 disk 
sdd               8:48   0    5G  0 disk 
sde               8:64   0    5G  0 disk 
sdf               8:80   0    5G  0 disk 
sr0              11:0    1 1024M  0 rom  


### Создаем 10й рейд из sdb sdc sdd sde

[root@ubuntu2402]:~# mdadm --create /dev/md0 --level=10 --raid-devices=4 /dev/sdb /dev/sdc /dev/sdd /dev/sde

root@ubuntu2402:~# cat /proc/mdstat
Personalities : [raid0] [raid1] [raid6] [raid5] [raid4] [raid10] 
md0 : active raid10 sde[3] sdd[2] sdc[1] sdb[0]
      10475520 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
      
unused devices: <none>


### Смотрим статус рейда

[root@ubuntu2402]:~# mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Thu Oct 16 18:56:41 2025
        Raid Level : raid10
        Array Size : 10475520 (9.99 GiB 10.73 GB)
     Used Dev Size : 5237760 (5.00 GiB 5.36 GB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Thu Oct 16 18:57:34 2025
             State : clean 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : ubuntu2402:0  (local to host ubuntu2402)
              UUID : eb4762af:d1c56bb2:77b557be:5f9ff400
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde

###Делаем разметку GPT 

[root@ubuntu2402]:~# parted -s /dev/md0 mklabel gpt
[root@ubuntu2402]:~# parted -s /dev/md0 mkpart primary ext4 0% 20%
parted -s /dev/md0 mkpart primary ext4 20% 40%
parted -s /dev/md0 mkpart primary ext4 40% 60%
parted -s /dev/md0 mkpart primary ext4 60% 80%
parted -s /dev/md0 mkpart primary ext4 80% 100%

###Смотрим что получилось

[root@ubuntu2402]:~# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINTS
sda               8:0    0   50G  0 disk   
├─sda1            8:1    0    1M  0 part   
├─sda2            8:2    0    2G  0 part   /boot
└─sda3            8:3    0   48G  0 part   
  ├─system-root 252:0    0   10G  0 lvm    /
  ├─system-home 252:1    0   10G  0 lvm    /home
  ├─system-var  252:2    0   10G  0 lvm    /var
  ├─system-log  252:3    0   10G  0 lvm    /var/log
  ├─system-swap 252:4    0    3G  0 lvm    [SWAP]
  └─system-tmp  252:5    0    5G  0 lvm    /tmp
sdb               8:16   0    5G  0 disk   
└─md0             9:0    0   10G  0 raid10 
  ├─md0p5       259:0    0    2G  0 part   
  ├─md0p1       259:5    0    2G  0 part   
  ├─md0p2       259:6    0    2G  0 part   
  ├─md0p3       259:7    0    2G  0 part   
  └─md0p4       259:8    0    2G  0 part   
sdc               8:32   0    5G  0 disk   
└─md0             9:0    0   10G  0 raid10 
  ├─md0p5       259:0    0    2G  0 part   
  ├─md0p1       259:5    0    2G  0 part   
  ├─md0p2       259:6    0    2G  0 part   
  ├─md0p3       259:7    0    2G  0 part   
  └─md0p4       259:8    0    2G  0 part   
sdd               8:48   0    5G  0 disk   
└─md0             9:0    0   10G  0 raid10 
  ├─md0p5       259:0    0    2G  0 part   
  ├─md0p1       259:5    0    2G  0 part   
  ├─md0p2       259:6    0    2G  0 part   
  ├─md0p3       259:7    0    2G  0 part   
  └─md0p4       259:8    0    2G  0 part   
sde               8:64   0    5G  0 disk   
└─md0             9:0    0   10G  0 raid10 
  ├─md0p5       259:0    0    2G  0 part   
  ├─md0p1       259:5    0    2G  0 part   
  ├─md0p2       259:6    0    2G  0 part   
  ├─md0p3       259:7    0    2G  0 part   
  └─md0p4       259:8    0    2G  0 part   
sdf               8:80   0    5G  0 disk   
sr0              11:0    1 1024M  0 rom    


###Прописываем файловую систему 

[root@ubuntu2402]:~# for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done

###Создаем точки монтирования

[root@ubuntu2402]:~# mkdir -p /raid/part{1,2,3,4,5}

###Монтируем

[root@ubuntu2402]:~# for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done

###смотрим

[root@ubuntu2402]:~# df -h
Filesystem               Size  Used Avail Use% Mounted on
tmpfs                    392M  1.7M  390M   1% /run
/dev/mapper/system-root  9.8G  2.7G  6.7G  29% /
tmpfs                    2.0G     0  2.0G   0% /dev/shm
tmpfs                    5.0M     0  5.0M   0% /run/lock
/dev/mapper/system-tmp   4.9G   68K  4.6G   1% /tmp
/dev/mapper/system-home  9.8G  100K  9.3G   1% /home
/dev/mapper/system-var   9.8G  1.3G  8.1G  14% /var
/dev/mapper/system-log   9.8G  102M  9.2G   2% /var/log
/dev/sda2                2.0G  197M  1.6G  11% /boot
tmpfs                    392M   12K  392M   1% /run/user/1001
/dev/md0p1               2.0G   24K  1.9G   1% /raid/part1
/dev/md0p2               2.0G   24K  1.9G   1% /raid/part2
/dev/md0p3               2.0G   24K  1.9G   1% /raid/part3
/dev/md0p4               2.0G   24K  1.9G   1% /raid/part4
/dev/md0p5               2.0G   24K  1.9G   1% /raid/part5

——

### допустим диск sde отхлебнул, фейлим его, удаляем, добавляем вместо него sdf

[root@ubuntu2402]:~# mdadm /dev/md0 --fail /dev/sde
[root@ubuntu2402]:~# mdadm /dev/md0 --remove /dev/sde
[root@ubuntu2402]:~# mdadm /dev/md0 --add /dev/sdf

### смотрим статус рейда, ресинк, ждем

[root@ubuntu2402]:~# mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Thu Oct 16 18:56:41 2025
        Raid Level : raid10
        Array Size : 10475520 (9.99 GiB 10.73 GB)
     Used Dev Size : 5237760 (5.00 GiB 5.36 GB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Thu Oct 16 19:13:18 2025
             State : clean, degraded, recovering 
    Active Devices : 3
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 1

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

    Rebuild Status : 11% complete

              Name : ubuntu2402:0  (local to host ubuntu2402)
              UUID : eb4762af:d1c56bb2:77b557be:5f9ff400
            Events : 24

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       4       8       80        3      spare rebuilding   /dev/sdf

### смотрим статус рейда, clean

[root@ubuntu2402]:~# mdadm --detail /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Thu Oct 16 18:56:41 2025
        Raid Level : raid10
        Array Size : 10475520 (9.99 GiB 10.73 GB)
     Used Dev Size : 5237760 (5.00 GiB 5.36 GB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Thu Oct 16 19:13:43 2025
             State : clean 
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : ubuntu2402:0  (local to host ubuntu2402)
              UUID : eb4762af:d1c56bb2:77b557be:5f9ff400
            Events : 40

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       4       8       80        3      active sync set-B   /dev/sdf

