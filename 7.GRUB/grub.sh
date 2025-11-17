Редактируем граб , задаем таймаут загрузки:

root@ubuntu2402:~# nano /etc/default/grub

GRUB_DEFAULT=0
#GRUB_TIMEOUT_STYLE=hidden
GRUB_TIMEOUT=10
GRUB_DISTRIBUTOR=`( . /etc/os-release; echo ${NAME:-Ubuntu} ) 2>/dev/null || echo Ubuntu`
GRUB_CMDLINE_LINUX_DEFAULT="ipv6.disable=1"
GRUB_CMDLINE_LINUX="ipv6.disable=1"


Обновляем

root@ubuntu2402:~# update-grub

Sourcing file `/etc/default/grub'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.8.0-87-generic
Found initrd image: /boot/initrd.img-6.8.0-87-generic
Found linux image: /boot/vmlinuz-6.8.0-85-generic
Found initrd image: /boot/initrd.img-6.8.0-85-generic
Found linux image: /boot/vmlinuz-6.8.0-60-generic
Found initrd image: /boot/initrd.img-6.8.0-60-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done

ребутаем

root@ubuntu2402:~# reboot


С консоли заходим через баш инит или адванс мод. (в сроке с linux - добавляем init=bin/bash, получилось)


root@ubuntu2402:~# vgs
  VG     #PV #LV #SN Attr   VSize   VFree
  system   1   6   0 wz--n- <48.00g    0 


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
sdg               8:96   0    5G  0 disk 
sdh               8:112  0    5G  0 disk 
sdi               8:128  0    5G  0 disk 
sr0              11:0    1 1024M  0 rom  


root@ubuntu2402:~# vgrename system ubuntu-otus

root@ubuntu2402:~# nano /boot/grub/grub.cfg

root@ubuntu2402:~# reboot

root@ubuntu2402:~# vgs
  VG          #PV #LV #SN Attr   VSize   VFree
  ubuntu-otus   1   6   0 wz--n- <48.00g    0 
