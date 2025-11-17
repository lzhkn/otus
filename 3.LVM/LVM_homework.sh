root@ubuntu2402:~# lsblk
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


-----

Подготовим временный том для / раздела,включая файловую систему:

-----
root@ubuntu2402:~# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.

root@ubuntu2402:~# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created

root@ubuntu2402:~# lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created.

root@ubuntu2402:~# mkfs.ext4 /dev/vg_root/lv_root

mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 1309696 4k blocks and 327680 inodes
Filesystem UUID: 277dbe8d-c5ae-4b4a-8762-d33c504f2ca2
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376, 294912, 819200, 884736

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

root@ubuntu2402:~# mount /dev/vg_root/lv_root /mnt

root@ubuntu2402:~# lsblk
NAME              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                 8:0    0   50G  0 disk 
├─sda1              8:1    0    1M  0 part 
├─sda2              8:2    0    2G  0 part /boot
└─sda3              8:3    0   48G  0 part 
  ├─system-root   252:0    0   10G  0 lvm  /
  ├─system-home   252:1    0   10G  0 lvm  /home
  ├─system-var    252:2    0   10G  0 lvm  /var
  ├─system-log    252:3    0   10G  0 lvm  /var/log
  ├─system-swap   252:4    0    3G  0 lvm  [SWAP]
  └─system-tmp    252:5    0    5G  0 lvm  /tmp
sdb                 8:16   0    5G  0 disk 
└─vg_root-lv_root 252:6    0    5G  0 lvm  /mnt
sdc                 8:32   0    5G  0 disk 
sdd                 8:48   0    5G  0 disk 
sde                 8:64   0    5G  0 disk 
sdf                 8:80   0    5G  0 disk 
sr0                11:0    1 1024M  0 rom  

------

Копируем все данные с / раздела в /mnt

Затем сконфигурируем grub для того, чтобы при старте перейти в новый /.
Сымитируем текущий root, сделаем в него chroot и обновим grub:


------

root@ubuntu2402:~# rsync -avxHAX --progress / /mnt/

sent 2,501,096,992 bytes  received 2,258,063 bytes  9,609,808.27 bytes/sec
total size is 2,496,517,785  speedup is 1.00

root@ubuntu2402:~# for i in /proc/ /sys/ /dev/ /run/ /boot/;  do mount --bind $i /mnt/$i; done

root@ubuntu2402:~# for i in /proc/ /sys/ /dev/ /run/ /boot/; \
 do mount --bind $i /mnt/$i; done

root@ubuntu2402:~# chroot /mnt/

root@ubuntu2402:/# grub-mkconfig -o /boot/grub/grub.cfg

Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.0-85-generic
Found initrd image: /boot/initrd.img-6.8.0-85-generic
Found linux image: /boot/vmlinuz-6.8.0-60-generic
Found initrd image: /boot/initrd.img-6.8.0-60-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done

---------
Обновим образ initrd. 
---------

root@ubuntu2402:/# update-initramfs -u

update-initramfs: Generating /boot/initrd.img-6.8.0-85-generic
mktemp: failed to create directory via template ‘/var/tmp/mkinitramfs_XXXXXX’: No such file or directory
update-initramfs: failed for /boot/initrd.img-6.8.0-85-generic with 1.

root@ubuntu2402:/# ls /var/tmp

ls: cannot access '/var/tmp': No such file or directory

root@ubuntu2402:/# mkdir /var/tmp

root@ubuntu2402:/# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.8.0-85-generic

root@ubuntu2402:/# exit

root@ubuntu2402:# reboot

------------
Посмотрим картину с дисками после перезагрузки:
------------

root@ubuntu2402:~# lsblk
NAME              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                 8:0    0   50G  0 disk 
├─sda1              8:1    0    1M  0 part 
├─sda2              8:2    0    2G  0 part /boot
└─sda3              8:3    0   48G  0 part 
  ├─system-root   252:1    0   10G  0 lvm  
  ├─system-home   252:2    0   10G  0 lvm  /home
  ├─system-var    252:3    0   10G  0 lvm  /var
  ├─system-log    252:4    0   10G  0 lvm  /var/log
  ├─system-swap   252:5    0    3G  0 lvm  [SWAP]
  └─system-tmp    252:6    0    5G  0 lvm  /tmp
sdb                 8:16   0    5G  0 disk 
└─vg_root-lv_root 252:0    0    5G  0 lvm  /
sdc                 8:32   0    5G  0 disk 
sdd                 8:48   0    5G  0 disk 
sde                 8:64   0    5G  0 disk 
sdf                 8:80   0    5G  0 disk 
sr0                11:0    1 1024M  0 rom  


-----------------
Теперь создаём новый VG на 8G:
-----------------

root@ubuntu2402:~# vgcreate ubuntu-vg /dev/sd{e,f}
  Physical volume "/dev/sde" successfully created.
  Physical volume "/dev/sdf" successfully created.
  Volume group "ubuntu-vg" successfully created
root@ubuntu2402:~# lsblk
NAME              MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                 8:0    0   50G  0 disk 
├─sda1              8:1    0    1M  0 part 
├─sda2              8:2    0    2G  0 part /boot
└─sda3              8:3    0   48G  0 part 
  ├─system-root   252:1    0   10G  0 lvm  
  ├─system-home   252:2    0   10G  0 lvm  /home
  ├─system-var    252:3    0   10G  0 lvm  /var
  ├─system-log    252:4    0   10G  0 lvm  /var/log
  ├─system-swap   252:5    0    3G  0 lvm  [SWAP]
  └─system-tmp    252:6    0    5G  0 lvm  /tmp
sdb                 8:16   0    5G  0 disk 
└─vg_root-lv_root 252:0    0    5G  0 lvm  /
sdc                 8:32   0    5G  0 disk 
sdd                 8:48   0    5G  0 disk 
sde                 8:64   0    5G  0 disk 
sdf                 8:80   0    5G  0 disk 
sr0                11:0    1 1024M  0 rom  
root@ubuntu2402:~# vgs
  VG        #PV #LV #SN Attr   VSize   VFree
  system      1   6   0 wz--n- <48.00g    0 
  ubuntu-vg   2   0   0 wz--n-   9.99g 9.99g
  vg_root     1   1   0 wz--n-  <5.00g    0 
root@ubuntu2402:~# lvcreate -n ubuntu-vg/ubuntu-lv -L 8G /dev/ubuntu-vg
  Logical volume "ubuntu-lv" created.

root@ubuntu2402:~# mkfs.ext4 /dev/ubuntu-vg/ubuntu-lv
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 2097152 4k blocks and 524288 inodes
Filesystem UUID: 821b2815-10dd-481c-a94d-c187ac47262f
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (16384 blocks): done
Writing superblocks and filesystem accounting information: done 

root@ubuntu2402:~# mount /dev/ubuntu-vg/ubuntu-lv /mnt

root@ubuntu2402:~# rsync -avxHAX --progress / /mnt/

sent 2,501,094,582 bytes  received 2,258,317 bytes  9,323,474.48 bytes/sec
total size is 2,496,520,851  speedup is 1.00

--------------
Так же как в первый раз cконфигурируем grub.
--------------

root@ubuntu2402:/# grub-mkconfig -o /boot/grub/grub.cfg
Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.0-85-generic
Found initrd image: /boot/initrd.img-6.8.0-85-generic
Found linux image: /boot/vmlinuz-6.8.0-60-generic
Found initrd image: /boot/initrd.img-6.8.0-60-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done

root@ubuntu2402:/# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.8.0-85-generic
mktemp: failed to create directory via template ‘/var/tmp/mkinitramfs_XXXXXX’: No such file or directory
update-initramfs: failed for /boot/initrd.img-6.8.0-85-generic with 1.
root@ubuntu2402:/# mkdir /var/tmp
root@ubuntu2402:/# update-initramfs -u
update-initramfs: Generating /boot/initrd.img-6.8.0-85-generic


-----------------

Выделим том под /var в зеркало
На свободных дисках создаем зеркало:

-----------------

root@ubuntu2402:/# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINTS
sda                       8:0    0   50G  0 disk 
├─sda1                    8:1    0    1M  0 part 
├─sda2                    8:2    0    2G  0 part /boot
└─sda3                    8:3    0   48G  0 part 
  ├─system-root         252:1    0   10G  0 lvm  
  ├─system-home         252:2    0   10G  0 lvm  
  ├─system-var          252:3    0   10G  0 lvm  
  ├─system-log          252:4    0   10G  0 lvm  
  ├─system-swap         252:5    0    3G  0 lvm  [SWAP]
  └─system-tmp          252:6    0    5G  0 lvm  
sdb                       8:16   0    5G  0 disk 
└─vg_root-lv_root       252:0    0    5G  0 lvm  
sdc                       8:32   0    5G  0 disk 
sdd                       8:48   0    5G  0 disk 
sde                       8:64   0    5G  0 disk 
└─ubuntu--vg-ubuntu--lv 252:7    0    8G  0 lvm  /
sdf                       8:80   0    5G  0 disk 
└─ubuntu--vg-ubuntu--lv 252:7    0    8G  0 lvm  /
sr0                      11:0    1 1024M  0 rom  
root@ubuntu2402:/#  pvcreate /dev/sdc /dev/sdd
  Physical volume "/dev/sdc" successfully created.
  Physical volume "/dev/sdd" successfully created.

root@ubuntu2402:/# vgcreate vg_var /dev/sdc /dev/sdd
  Volume group "vg_var" successfully created

root@ubuntu2402:/# lvcreate -L 950M -m1 -n lv_var vg_var
  Rounding up size to full physical extent 952.00 MiB
  Logical volume "lv_var" created.

root@ubuntu2402:/# mkfs.ext4 /dev/vg_var/lv_var
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 243712 4k blocks and 60928 inodes
Filesystem UUID: d43b6220-d6b7-4ba7-b8bb-3522600dd426
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

root@ubuntu2402:/# mount /dev/vg_var/lv_var /mnt

root@ubuntu2402:/# cp -aR /var/* /mnt/

root@ubuntu2402:/# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar

-----------

монтируем новый var в каталог /var:

-----------
root@ubuntu2402:/# umount /mnt

root@ubuntu2402:/# mount /dev/vg_var/lv_var /var

root@ubuntu2402:/# echo "`blkid | grep var: | awk '{print $2}'` \
 /var ext4 defaults 0 0" >> /etc/fstab

root@ubuntu2402:/# reboot

root@ubuntu2402:~# lvremove -f /dev/vg_root/lv_root
  Logical volume "lv_root" successfully removed.

root@ubuntu2402:~# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed
root@ubuntu2402:~# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.


--------
Выделяем том под /home по тому же принципу что делали для /var:
--------

root@ubuntu2402:~# lvcreate -n LogVol_Home -L 1G /dev/ubuntu-vg
  Logical volume "LogVol_Home" created.

root@ubuntu2402:~# mkfs.ext4 /dev/ubuntu-vg/LogVol_Home
mke2fs 1.47.0 (5-Feb-2023)
Discarding device blocks: done                            
Creating filesystem with 262144 4k blocks and 65536 inodes
Filesystem UUID: 6bb8dcff-a5a9-4d2d-9955-5ae3a78a2ef4
Superblock backups stored on blocks: 
        32768, 98304, 163840, 229376

Allocating group tables: done                            
Writing inode tables: done                            
Creating journal (8192 blocks): done
Writing superblocks and filesystem accounting information: done

root@ubuntu2402:~# mount /dev/ubuntu-vg/LogVol_Home /mnt/
root@ubuntu2402:~# cp -aR /home/* /mnt/
root@ubuntu2402:~# rm -rf /home/*
root@ubuntu2402:~# umount /mnt
root@ubuntu2402:~# mount /dev/ubuntu-vg/LogVol_Home /home/
root@ubuntu2402:~# echo "`blkid | grep Home | awk '{print $2}'` \
 /home xfs defaults 0 0" >> /etc/fstab


 -----------
Работа со снапшотами
Генерируем файлы в /home/:
 -----------

 root@ubuntu2402:~# touch /home/file{1..20}
root@ubuntu2402:~# lvcreate -L 100MB -s -n home_snap \
 /dev/ubuntu-vg/LogVol_Home
  Logical volume "home_snap" created.
root@ubuntu2402:~# rm -f /home/file{11..20}
root@ubuntu2402:~# umount /home
root@ubuntu2402:~# lvconvert --merge /dev/ubuntu-vg/home_snap
  Merging of volume ubuntu-vg/home_snap started.
  ubuntu-vg/LogVol_Home: Merged: 100.00%