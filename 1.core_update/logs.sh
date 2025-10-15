#repo for home works otus

###core update to vps ubuntu 24

~$ uname -rp
6.8.0-85-generic x86_64


~$ sudo wget https://kernel.ubuntu.com/mainline/v6.17/amd64/amd64/linux-headers-6.17.0-061700_6.17.0-061700.202509282239_all.deb
~$ sudo wget https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-headers-6.17.0-061700_6.17.0-061700.202509282239_all.deb
~$ sudo wget https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-image-unsigned-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb
~$ sudo wget https://kernel.ubuntu.com/mainline/v6.17/amd64/linux-modules-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb
~$ sudo dpkg -i *.deb 

###Вывалилась ошибка зависимостей

dpkg -i linux-headers-6.17.0-061700*.deb linux-modules-6.17.0-061700-generic*.deb linux-image-unsigned-6.17.0-061700-generic*.deb
(Reading database ... 146412 files and directories currently installed.)
Preparing to unpack linux-headers-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb ...
Unpacking linux-headers-6.17.0-061700-generic (6.17.0-061700.202509282239) over (6.17.0-061700.202509282239) ...
Preparing to unpack linux-headers-6.17.0-061700_6.17.0-061700.202509282239_all.deb ...
Unpacking linux-headers-6.17.0-061700 (6.17.0-061700.202509282239) over (6.17.0-061700.202509282239) ...
Preparing to unpack linux-modules-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb ...
Unpacking linux-modules-6.17.0-061700-generic (6.17.0-061700.202509282239) over (6.17.0-061700.202509282239) ...
Preparing to unpack linux-image-unsigned-6.17.0-061700-generic_6.17.0-061700.202509282239_amd64.deb ...
Unpacking linux-image-unsigned-6.17.0-061700-generic (6.17.0-061700.202509282239) over (6.17.0-061700.202509282239) ...
Setting up linux-headers-6.17.0-061700 (6.17.0-061700.202509282239) ...
dpkg: dependency problems prevent configuration of linux-modules-6.17.0-061700-generic:
 linux-modules-6.17.0-061700-generic depends on wireless-regdb; however:
  Package wireless-regdb is not installed.

dpkg: error processing package linux-modules-6.17.0-061700-generic (--install):
 dependency problems - leaving unconfigured
dpkg: dependency problems prevent configuration of linux-image-unsigned-6.17.0-061700-generic:
 linux-image-unsigned-6.17.0-061700-generic depends on linux-modules-6.17.0-061700-generic; however:
  Package linux-modules-6.17.0-061700-generic is not configured yet.

dpkg: error processing package linux-image-unsigned-6.17.0-061700-generic (--install):
 dependency problems - leaving unconfigured
Setting up linux-headers-6.17.0-061700-generic (6.17.0-061700.202509282239) ...
Errors were encountered while processing:
 linux-modules-6.17.0-061700-generic
 linux-image-unsigned-6.17.0-061700-generic


###Исправляем нарушенные зависимости

~$ sudo apt -f install

Reading package lists... Done
Building dependency tree... Done
Reading state information... Done
Correcting dependencies... Done
The following additional packages will be installed:
  wireless-regdb
The following NEW packages will be installed:
  wireless-regdb
0 upgraded, 1 newly installed, 0 to remove and 0 not upgraded.
2 not fully installed or removed.
Need to get 7344 B of archives.
After this operation, 24.6 kB of additional disk space will be used.
Do you want to continue? [Y/n] y
Get:1 http://nova.clouds.archive.ubuntu.com/ubuntu noble-updates/main amd64 wireless-regdb all 2024.10.07-0ubuntu2~24.04.1 [7344 B]
Fetched 7344 B in 0s (27.1 kB/s)
Selecting previously unselected package wireless-regdb.
(Reading database ... 146412 files and directories currently installed.)
Preparing to unpack .../wireless-regdb_2024.10.07-0ubuntu2~24.04.1_all.deb ...
Unpacking wireless-regdb (2024.10.07-0ubuntu2~24.04.1) ...
Setting up wireless-regdb (2024.10.07-0ubuntu2~24.04.1) ...
Setting up linux-modules-6.17.0-061700-generic (6.17.0-061700.202509282239) ...
Setting up linux-image-unsigned-6.17.0-061700-generic (6.17.0-061700.202509282239) ...
Processing triggers for man-db (2.12.0-4build2) ...
Processing triggers for linux-image-unsigned-6.17.0-061700-generic (6.17.0-061700.202509282239) ...
/etc/kernel/postinst.d/initramfs-tools:
update-initramfs: Generating /boot/initrd.img-6.17.0-061700-generic
/etc/kernel/postinst.d/zz-update-grub:
Sourcing file `/etc/default/grub'
Sourcing file `/etc/default/grub.d/50-cloudimg-settings.cfg'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.17.0-061700-generic
Found initrd image: /boot/initrd.img-6.17.0-061700-generic
Found linux image: /boot/vmlinuz-6.8.0-85-generic
Found initrd image: /boot/initrd.img-6.8.0-85-generic
Found linux image: /boot/vmlinuz-6.8.0-35-generic
Found initrd image: /boot/initrd.img-6.8.0-35-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done
needrestart is being skipped since dpkg has failed

###Видим что образы ядра найдены, обновляем загрузчик:

sudo update-grub
Sourcing file `/etc/default/grub'
Sourcing file `/etc/default/grub.d/50-cloudimg-settings.cfg'
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-6.17.0-061700-generic
Found initrd image: /boot/initrd.img-6.17.0-061700-generic
Found linux image: /boot/vmlinuz-6.8.0-85-generic
Found initrd image: /boot/initrd.img-6.8.0-85-generic
Found linux image: /boot/vmlinuz-6.8.0-35-generic
Found initrd image: /boot/initrd.img-6.8.0-35-generic
Warning: os-prober will not be executed to detect other bootable partitions.
Systems on them will not be added to the GRUB boot configuration.
Check GRUB_DISABLE_OS_PROBER documentation entry.
Adding boot menu entry for UEFI Firmware Settings ...
done

~$ sudo grub-set-default 0
~$ sudo reboot
~$ uname -r
6.17.0-061700-generic

###done
