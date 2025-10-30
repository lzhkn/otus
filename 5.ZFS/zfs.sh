1. Определение алгоритма с наилучшим сжатием


Установим пакет утилит для ZFS:

root@ubuntu2402:~# apt install zfsutils-linux

Создаём пул из двух дисков в режиме RAID 1:

root@ubuntu2402:~#  zpool create otus1 mirror /dev/sdb /dev/sdc

Создадим ещё 3 пула: 

root@ubuntu2402:~# zpool create otus2 mirror /dev/sdd /dev/sde
root@ubuntu2402:~# zpool create otus3 mirror /dev/sdf /dev/sdg
root@ubuntu2402:~# zpool create otus4 mirror /dev/sdh /dev/sdi


Смотрим информацию о пулах:

root@ubuntu2402:~# zpool list

NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1  4.50G   146K  4.50G        -         -     0%     0%  1.00x  SUSPENDED  -
otus2  4.50G   108K  4.50G        -         -     0%     0%  1.00x    ONLINE  -
otus3  4.50G   110K  4.50G        -         -     0%     0%  1.00x    ONLINE  -
otus4  4.50G   112K  4.50G        -         -     0%     0%  1.00x    ONLINE  -

Добавим разные алгоритмы сжатия в каждую файловую систему:

root@ubuntu2402:~# zfs set compression=lzjb otus1
root@ubuntu2402:~# zfs set compression=lz4 otus2
root@ubuntu2402:~# zfs set compression=gzip-9 otus3
root@ubuntu2402:~# zfs set compression=zle otus4

root@ubuntu2402:~# zfs get all | grep compression
otus1  compression           lzjb                   local
otus2  compression           lz4                    local
otus3  compression           gzip-9                 local
otus4  compression           zle                    local

root@ubuntu2402:~# for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done

--2025-10-30 14:23:10--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41181808 (39M) [text/plain]
Saving to: ‘/otus1/pg2600.converter.log’

pg2600.converter.log                100%[===================================================================>]  39.27M  4.71MB/s    in 9.4s    

2025-10-30 14:23:21 (4.16 MB/s) - ‘/otus1/pg2600.converter.log’ saved [41181808/41181808]

--2025-10-30 14:23:21--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41181808 (39M) [text/plain]
Saving to: ‘/otus2/pg2600.converter.log’

pg2600.converter.log                100%[===================================================================>]  39.27M  4.33MB/s    in 9.7s    

2025-10-30 14:23:31 (4.04 MB/s) - ‘/otus2/pg2600.converter.log’ saved [41181808/41181808]

--2025-10-30 14:23:31--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41181808 (39M) [text/plain]
Saving to: ‘/otus3/pg2600.converter.log’

pg2600.converter.log                100%[===================================================================>]  39.27M  4.07MB/s    in 10s     

2025-10-30 14:23:42 (3.86 MB/s) - ‘/otus3/pg2600.converter.log’ saved [41181808/41181808]

--2025-10-30 14:23:42--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47, 2610:28:3090:3000:0:bad:cafe:47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 41181808 (39M) [text/plain]
Saving to: ‘/otus4/pg2600.converter.log’

pg2600.converter.log                100%[===================================================================>]  39.27M  5.44MB/s    in 8.4s    

2025-10-30 14:23:51 (4.69 MB/s) - ‘/otus4/pg2600.converter.log’ saved [41181808/41181808]


Проверим, что файл был скачан во все пулы:


root@ubuntu2402:~# ls -l /otus*
/otus1:
total 22113
-rw-r--r-- 1 root root 41181808 Oct  2 10:31 pg2600.converter.log

/otus2:
total 18015
-rw-r--r-- 1 root root 41181808 Oct  2 10:31 pg2600.converter.log

/otus3:
total 10970
-rw-r--r-- 1 root root 41181808 Oct  2 10:31 pg2600.converter.log

/otus4:
total 40249
-rw-r--r-- 1 root root 41181808 Oct  2 10:31 pg2600.converter.log


Проверим, сколько места занимает один и тот же файл в разных пулах и проверим степень сжатия файлов:

root@ubuntu2402:~# zfs list
NAME    USED  AVAIL  REFER  MOUNTPOINT
otus1  21.7M  4.34G  21.6M  /otus1
otus2  17.7M  4.34G  17.6M  /otus2
otus3  10.8M  4.35G  10.7M  /otus3
otus4  39.4M  4.32G  39.3M  /otus4

root@ubuntu2402:~# zfs get all | grep compressratio | grep -v ref
otus1  compressratio         1.82x                  -
otus2  compressratio         2.23x                  -
otus3  compressratio         3.67x                  -
otus4  compressratio         1.00x                  -

Таким образом, у нас получается, что алгоритм gzip-9 самый эффективный по сжатию. 


2. Определение настроек пула


 root@ubuntu2402:~#  wget -O archive.tar.gz --no-check-certificate 'https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download' 
--2025-10-30 14:26:37--  https://drive.usercontent.google.com/download?id=1MvrcEp-WgAQe57aDEzxSRalPAwbNN1Bb&export=download
Resolving drive.usercontent.google.com (drive.usercontent.google.com)... 74.125.131.132, 2a00:1450:4010:c0e::84
Connecting to drive.usercontent.google.com (drive.usercontent.google.com)|74.125.131.132|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 7275140 (6.9M) [application/octet-stream]
Saving to: ‘archive.tar.gz’

archive.tar.gz                   100%[=======================================================>]   6.94M  16.0MB/s    in 0.4s    

2025-10-30 14:26:45 (16.0 MB/s) - ‘archive.tar.gz’ saved [7275140/7275140]

root@ubuntu2402:~# tar -xzvf archive.tar.gz

zpoolexport/
zpoolexport/filea
zpoolexport/fileb

Проверим, возможно ли импортировать данный каталог в пул:


root@ubuntu2402:~#  zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
        (Note that they may be intentionally disabled if the
        'compatibility' property is set.)
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                         ONLINE
          mirror-0                   ONLINE
            /root/zpoolexport/filea  ONLINE
            /root/zpoolexport/fileb  ONLINE


Данный вывод показывает нам имя пула, тип raid и его состав. 
Сделаем импорт данного пула к нам в ОС:

root@ubuntu2402:~# zpool import -d zpoolexport/ otus
root@ubuntu2402:~# zpool status
  pool: otus
 state: ONLINE
status: Some supported and requested features are not enabled on the pool.
        The pool can still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(7) for details.
config:

        NAME                         STATE     READ WRITE CKSUM
        otus                         ONLINE       0     0     0
          mirror-0                   ONLINE       0     0     0
            /root/zpoolexport/filea  ONLINE       0     0     0
            /root/zpoolexport/fileb  ONLINE       0     0     0

errors: No known data errors

  pool: otus1
 state: ONLINE
config:

        NAME        STATE     READ WRITE CKSUM
        otus1       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdb     ONLINE       0     0     0
            sdc     ONLINE       0     0     0

errors: No known data errors

  pool: otus2
 state: ONLINE
config:

        NAME        STATE     READ WRITE CKSUM
        otus2       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdd     ONLINE       0     0     0
            sde     ONLINE       0     0     0

errors: No known data errors

  pool: otus3
 state: ONLINE
config:

        NAME        STATE     READ WRITE CKSUM
        otus3       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdf     ONLINE       0     0     0
            sdg     ONLINE       0     0     0

errors: No known data errors

  pool: otus4
 state: ONLINE
config:

        NAME        STATE     READ WRITE CKSUM
        otus4       ONLINE       0     0     0
          mirror-0  ONLINE       0     0     0
            sdh     ONLINE       0     0     0
            sdi     ONLINE       0     0     0

errors: No known data errors

Команда zpool status выдаст нам информацию о составе импортированного пула.

Далее нам нужно определить настройки

Запрос сразу всех параметром файловой системы:

root@ubuntu2402:~# zpool get all otus
NAME  PROPERTY                       VALUE                          SOURCE
otus  size                           480M                           -
otus  capacity                       0%                             -
otus  altroot                        -                              default
otus  health                         ONLINE                         -
otus  guid                           6554193320433390805            -
otus  version                        -                              default
otus  bootfs                         -                              default
otus  delegation                     on                             default
otus  autoreplace                    off                            default
otus  cachefile                      -                              default
otus  failmode                       wait                           default
otus  listsnapshots                  off                            default
otus  autoexpand                     off                            default
otus  dedupratio                     1.00x                          -
otus  free                           478M                           -
otus  allocated                      2.09M                          -
otus  readonly                       off                            -
otus  ashift                         0                              default
otus  comment                        -                              default
otus  expandsize                     -                              -
otus  freeing                        0                              -
otus  fragmentation                  0%                             -
otus  leaked                         0                              -
otus  multihost                      off                            default
otus  checkpoint                     -                              -
otus  load_guid                      6952430745833169224            -
otus  autotrim                       off                            default
otus  compatibility                  off                            default
otus  bcloneused                     0                              -
otus  bclonesaved                    0                              -
otus  bcloneratio                    1.00x                          -
otus  feature@async_destroy          enabled                        local
otus  feature@empty_bpobj            active                         local
otus  feature@lz4_compress           active                         local
otus  feature@multi_vdev_crash_dump  enabled                        local
otus  feature@spacemap_histogram     active                         local
otus  feature@enabled_txg            active                         local
otus  feature@hole_birth             active                         local
otus  feature@extensible_dataset     active                         local
otus  feature@embedded_data          active                         local
otus  feature@bookmarks              enabled                        local
otus  feature@filesystem_limits      enabled                        local
otus  feature@large_blocks           enabled                        local
otus  feature@large_dnode            enabled                        local
otus  feature@sha512                 enabled                        local
otus  feature@skein                  enabled                        local
otus  feature@edonr                  enabled                        local
otus  feature@userobj_accounting     active                         local
otus  feature@encryption             enabled                        local
otus  feature@project_quota          active                         local
otus  feature@device_removal         enabled                        local
otus  feature@obsolete_counts        enabled                        local
otus  feature@zpool_checkpoint       enabled                        local
otus  feature@spacemap_v2            active                         local
otus  feature@allocation_classes     enabled                        local
otus  feature@resilver_defer         enabled                        local
otus  feature@bookmark_v2            enabled                        local
otus  feature@redaction_bookmarks    disabled                       local
otus  feature@redacted_datasets      disabled                       local
otus  feature@bookmark_written       disabled                       local
otus  feature@log_spacemap           disabled                       local
otus  feature@livelist               disabled                       local
otus  feature@device_rebuild         disabled                       local
otus  feature@zstd_compress          disabled                       local
otus  feature@draid                  disabled                       local
otus  feature@zilsaxattr             disabled                       local
otus  feature@head_errlog            disabled                       local
otus  feature@blake3                 disabled                       local
otus  feature@block_cloning          disabled                       local
otus  feature@vdev_zaps_v2           disabled                       local

root@ubuntu2402:~# zfs get all otus
NAME  PROPERTY              VALUE                  SOURCE
otus  type                  filesystem             -
otus  creation              Fri May 15  7:00 2020  -
otus  used                  2.04M                  -
otus  available             350M                   -
otus  referenced            24K                    -
otus  compressratio         1.00x                  -
otus  mounted               yes                    -
otus  quota                 none                   default
otus  reservation           none                   default
otus  recordsize            128K                   local
otus  mountpoint            /otus                  default
otus  sharenfs              off                    default
otus  checksum              sha256                 local
otus  compression           zle                    local
otus  atime                 on                     default
otus  devices               on                     default
otus  exec                  on                     default
otus  setuid                on                     default
otus  readonly              off                    default
otus  zoned                 off                    default
otus  snapdir               hidden                 default
otus  aclmode               discard                default
otus  aclinherit            restricted             default
otus  createtxg             1                      -
otus  canmount              on                     default
otus  xattr                 on                     default
otus  copies                1                      default
otus  version               5                      -
otus  utf8only              off                    -
otus  normalization         none                   -
otus  casesensitivity       sensitive              -
otus  vscan                 off                    default
otus  nbmand                off                    default
otus  sharesmb              off                    default
otus  refquota              none                   default
otus  refreservation        none                   default
otus  guid                  14592242904030363272   -
otus  primarycache          all                    default
otus  secondarycache        all                    default
otus  usedbysnapshots       0B                     -
otus  usedbydataset         24K                    -
otus  usedbychildren        2.01M                  -
otus  usedbyrefreservation  0B                     -
otus  logbias               latency                default
otus  objsetid              54                     -
otus  dedup                 off                    default
otus  mlslabel              none                   default
otus  sync                  standard               default
otus  dnodesize             legacy                 default
otus  refcompressratio      1.00x                  -
otus  written               24K                    -
otus  logicalused           1020K                  -
otus  logicalreferenced     12K                    -
otus  volmode               default                default
otus  filesystem_limit      none                   default
otus  snapshot_limit        none                   default
otus  filesystem_count      none                   default
otus  snapshot_count        none                   default
otus  snapdev               hidden                 default
otus  acltype               off                    default
otus  context               none                   default
otus  fscontext             none                   default
otus  defcontext            none                   default
otus  rootcontext           none                   default
otus  relatime              on                     default
otus  redundant_metadata    all                    default
otus  overlay               on                     default
otus  encryption            off                    default
otus  keylocation           none                   default
otus  keyformat             none                   default
otus  pbkdf2iters           0                      default
otus  special_small_blocks  0                      default


C помощью команды grep уточняем конкретный параметр


root@ubuntu2402:~# zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
root@ubuntu2402:~# zfs get readonly otus
NAME  PROPERTY  VALUE   SOURCE
otus  readonly  off     default

По типу FS мы можем понять, что позволяет выполнять чтение и запись

Значение recordsize:

root@ubuntu2402:~# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local

Тип сжатия (или параметр отключения)

root@ubuntu2402:~# zfs get compression otus
NAME  PROPERTY     VALUE           SOURCE
otus  compression  zle             local

Тип контрольной суммы:

root@ubuntu2402:~# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local


3. Работа со снапшотом, поиск сообщения от преподавателя

Скачаем файл, указанный в задании:

root@ubuntu2402:~# wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI&export=download
[1] 16401
root@ubuntu2402:~# 
Redirecting output to ‘wget-log’.


Восстановим файловую систему из снапшота:


root@ubuntu2402:~# zfs receive otus/test@today < otus_task2.file
[1]+  Done                    wget -O otus_task2.file --no-check-certificate https://drive.usercontent.google.com/download?id=1wgxjih8YZ-cqLqaZVa0lA3h3Y029c3oI


Смотрим содержимое найденного файла:


root@ubuntu2402:~# cat /otus/test/task1/file_mess/secret_message
https://otus.ru/lessons/linux-hl/