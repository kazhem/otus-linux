# ДЗ Дисковая подсистема. Работа с mdadm
## Добавить в Vagrantfile еще дисков;

Начальный стенд можно взять отсюда: https://github.com/erlong15/otus-linux

В Vagrantfile в секцию MACHINES:otuslinux:disks добавить новый диск (5й):
```
        :sata1 => {
			:dfile => './sata1.vdi',
			:size => 250,
			:port => 1
		},
        ...
        :sata5 => {
            :dfile => './sata5.vdi', # Путь, по которому будет создан файл диска
            :size => 250, # Размер диска в мегабайтах
            :port => 5 # Номер порта на который будет зацеплен диск
        }
```
## Собрать RAID0/1/5/10 - на выбор
Далее нужно определиться какого уровня RAID будем собирать. Для это посмотрим какие блочные устройства у нас есть и исходя из их кол-во, размера и поставленной задачи определимся.
Сделать это можно несколькими способами:

`fdisk -l`

`lsblk`

`lshw`

`lsscsi`
```
root@otuslinux vagrant]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sdf               8:80   0  250M  0 disk
sdd               8:48   0  250M  0 disk
sdb               8:16   0  250M  0 disk
sde               8:64   0  250M  0 disk
sdc               8:32   0  250M  0 disk
sda               8:0    0   10G  0 disk
├─sda2            8:2    0    9G  0 part
│ ├─centos-swap 253:1    0    1G  0 lvm  [SWAP]
│ └─centos-root 253:0    0    8G  0 lvm  /
└─sda1            8:1    0    1G  0 part /boot
```

```
[root@otuslinux vagrant]# lsscsi
[0:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sda
[3:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdb
[4:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdc
[5:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdd
[6:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sde
[7:0:0:0]    disk    ATA      VBOX HARDDISK    1.0   /dev/sdf
```


Необходимо установить утилиту mdadm, если ее нет
```
sudo yum install mdadm
```
Занулим на всякий случай суперблоки

```
[root@otuslinux vagrant]# mdadm --zero-superblock --force /dev/sd{b,c,d,e,f}
mdadm: Unrecognised md component device - /dev/sdb
mdadm: Unrecognised md component device - /dev/sdc
mdadm: Unrecognised md component device - /dev/sdd
mdadm: Unrecognised md component device - /dev/sde
mdadm: Unrecognised md component device - /dev/sdf
```

### Соберем raid10

```
[root@otuslinux vagrant]# mdadm --create --verbose /dev/md0 -l 10 -n 4 /dev/sd{b,c,d,e}
mdadm: layout defaults to n2
mdadm: layout defaults to n2
mdadm: chunk size defaults to 512K
mdadm: size set to 253952K
mdadm: Defaulting to version 1.2 metadata
mdadm: array /dev/md0 started.
```
- Опция-l какого уровня RAID создавать - 10
- Опция - n указывает на кол-во устройств в RAID - 4

Проверим, что RAID собрался нормально:
```
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10]
md0 : active raid10 sde[3] sdd[2] sdc[1] sdb[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
```


```
[root@otuslinux vagrant]# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Tue Feb 15 19:27:47 2022
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Tue Feb 15 19:27:50 2022
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : f4b694af:fa9dc54a:e8b2caf6:1c05a7f5
            Events : 17

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       3       8       64        3      active sync set-B   /dev/sde
```
## Создание конфигурационного файла mdadm.conf
Для того, чтобы быть уверенным что ОС запомнила какой RAID массив требуется создать и какие компоненты в него входят создадим файл mdadm.conf

Сначала убедимся, что информация верна

```
[root@otuslinux vagrant]# mdadm --detail --scan --verbose
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 name=otuslinux:0 UUID=f4b694af:fa9dc54a:e8b2caf6:1c05a7f5
   devices=/dev/sdb,/dev/sdc,/dev/sdd,/dev/sde
```
А затем в две команды создадим файл mdadm.conf
```
mkdir -p /etc/mdadm
echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
```
```
[root@otuslinux vagrant]# cat /etc/mdadm/mdadm.conf
DEVICE partitions
ARRAY /dev/md0 level=raid10 num-devices=4 metadata=1.2 name=otuslinux:0 UUID=f4b694af:fa9dc54a:e8b2caf6:1c05a7f5
```
## Сломать починить рейд
Сделать это можно, например, искусственно “зафейлив” одно из блочных устройств командной:

```
root@otuslinux vagrant]# mdadm /dev/md0 --fail /dev/sde
mdadm: set /dev/sde faulty in /dev/md0
```
Посмотрим как 'то отразилось на RAID:
```
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10]
md0 : active raid10 sde[3](F) sdd[2] sdc[1] sdb[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/3] [UUU_]
```
```
[root@otuslinux vagrant]# mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Tue Feb 15 19:27:47 2022
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Tue Feb 15 19:55:44 2022
             State : clean, degraded
    Active Devices : 3
   Working Devices : 3
    Failed Devices : 1
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : f4b694af:fa9dc54a:e8b2caf6:1c05a7f5
            Events : 19

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       -       0        0        3      removed

       3       8       64        -      faulty   /dev/sde
```

Удалим “сломанный” диск из массива:
```
[root@otuslinux vagrant]# mdadm /dev/md0 --remove /dev/sde
mdadm: hot removed /dev/sde from /dev/md0
```
Вставим новый диск /dev/sdf:
```
[root@otuslinux vagrant]# mdadm /dev/md0 --add /dev/sdf
mdadm: added /dev/sdf
```
```
[root@otuslinux vagrant]# cat /proc/mdstat
Personalities : [raid10]
md0 : active raid10 sdf[4] sdd[2] sdc[1] sdb[0]
      507904 blocks super 1.2 512K chunks 2 near-copies [4/4] [UUUU]
```
```
mdadm -D /dev/md0
/dev/md0:
           Version : 1.2
     Creation Time : Tue Feb 15 19:27:47 2022
        Raid Level : raid10
        Array Size : 507904 (496.00 MiB 520.09 MB)
     Used Dev Size : 253952 (248.00 MiB 260.05 MB)
      Raid Devices : 4
     Total Devices : 4
       Persistence : Superblock is persistent

       Update Time : Tue Feb 15 20:00:23 2022
             State : clean
    Active Devices : 4
   Working Devices : 4
    Failed Devices : 0
     Spare Devices : 0

            Layout : near=2
        Chunk Size : 512K

Consistency Policy : resync

              Name : otuslinux:0  (local to host otuslinux)
              UUID : f4b694af:fa9dc54a:e8b2caf6:1c05a7f5
            Events : 39

    Number   Major   Minor   RaidDevice State
       0       8       16        0      active sync set-A   /dev/sdb
       1       8       32        1      active sync set-B   /dev/sdc
       2       8       48        2      active sync set-A   /dev/sdd
       4       8       80        3      active sync set-B   /dev/sdf
```
RAID восстановлен с новым диском

## Создать GPT раздел, пять партиций и смонтировать их на диск
Создаем раздел GPT на RAID
```
parted -s /dev/md0 mklabel gpt
```
Создадим партиции
```
parted /dev/md0 mkpart primary ext4 0% 20%
parted /dev/md0 mkpart primary ext4 20% 40%
parted /dev/md0 mkpart primary ext4 40% 60%
parted /dev/md0 mkpart primary ext4 60% 80%
parted /dev/md0 mkpart primary ext4 80% 100%

...
Информация: Не забудьте обновить /etc/fstab.
```
Создадим на партициях ФС:
```
[root@otuslinux vagrant]# for i in $(seq 1 5); do sudo mkfs.ext4 /dev/md0p$i; done
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1024 blocks
25168 inodes, 100352 blocks
5017 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33685504
13 block groups
8192 blocks per group, 8192 fragments per group
1936 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1024 blocks
25376 inodes, 101376 blocks
5068 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33685504
13 block groups
8192 blocks per group, 8192 fragments per group
1952 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1024 blocks
25688 inodes, 102400 blocks
5120 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33685504
13 block groups
8192 blocks per group, 8192 fragments per group
1976 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1024 blocks
25376 inodes, 101376 blocks
5068 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33685504
13 block groups
8192 blocks per group, 8192 fragments per group
1952 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done

mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=1024 (log=0)
Fragment size=1024 (log=0)
Stride=512 blocks, Stripe width=1024 blocks
25168 inodes, 100352 blocks
5017 blocks (5.00%) reserved for the super user
First data block=1
Maximum filesystem blocks=33685504
13 block groups
8192 blocks per group, 8192 fragments per group
1936 inodes per group
Superblock backups stored on blocks:
        8193, 24577, 40961, 57345, 73729

Allocating group tables: done
Writing inode tables: done
Creating journal (4096 blocks): done
Writing superblocks and filesystem accounting information: done
```
И смонтируем их по каталогам:
```
mkdir -p /raid/part{1,2,3,4,5}
for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
```

```
[root@otuslinux vagrant]# lsblk
NAME            MAJ:MIN RM  SIZE RO TYPE   MOUNTPOINT
sdf               8:80   0  250M  0 disk
└─md0             9:0    0  496M  0 raid10
  ├─md0p4       259:8    0   99M  0 md     /raid/part4
  ├─md0p2       259:6    0   99M  0 md     /raid/part2
  ├─md0p5       259:9    0   98M  0 md     /raid/part5
  ├─md0p3       259:7    0  100M  0 md     /raid/part3
  └─md0p1       259:5    0   98M  0 md     /raid/part1
sdd               8:48   0  250M  0 disk
└─md0             9:0    0  496M  0 raid10
  ├─md0p4       259:8    0   99M  0 md     /raid/part4
  ├─md0p2       259:6    0   99M  0 md     /raid/part2
  ├─md0p5       259:9    0   98M  0 md     /raid/part5
  ├─md0p3       259:7    0  100M  0 md     /raid/part3
  └─md0p1       259:5    0   98M  0 md     /raid/part1
sdb               8:16   0  250M  0 disk
└─md0             9:0    0  496M  0 raid10
  ├─md0p4       259:8    0   99M  0 md     /raid/part4
  ├─md0p2       259:6    0   99M  0 md     /raid/part2
  ├─md0p5       259:9    0   98M  0 md     /raid/part5
  ├─md0p3       259:7    0  100M  0 md     /raid/part3
  └─md0p1       259:5    0   98M  0 md     /raid/part1
sde               8:64   0  250M  0 disk
sdc               8:32   0  250M  0 disk
└─md0             9:0    0  496M  0 raid10
  ├─md0p4       259:8    0   99M  0 md     /raid/part4
  ├─md0p2       259:6    0   99M  0 md     /raid/part2
  ├─md0p5       259:9    0   98M  0 md     /raid/part5
  ├─md0p3       259:7    0  100M  0 md     /raid/part3
  └─md0p1       259:5    0   98M  0 md     /raid/part1
sda               8:0    0   10G  0 disk
├─sda2            8:2    0    9G  0 part
│ ├─centos-swap 253:1    0    1G  0 lvm    [SWAP]
│ └─centos-root 253:0    0    8G  0 lvm    /
└─sda1            8:1    0    1G  0 part   /boot
```


# Здание со *
доп. задание - Vagrantfile, который сразу собирает систему с подключенным рейдом и смонтированными разделами. После перезагрузки стенда разделы должны автоматически примонтироваться.

Для загрузки добавлены provosion скрипты в Vagrantfile
```
        box.vm.provision "shell", path: "create_raid.sh"
        box.vm.provision "shell", inline: <<-SHELL
                mkdir -p /etc/mdadm
                echo "DEVICE partitions" > /etc/mdadm/mdadm.conf
                mdadm --detail --scan --verbose | awk '/ARRAY/ {print}' >> /etc/mdadm/mdadm.conf
        SHELL
        box.vm.provision "shell", inline: <<-SHELL
                parted -s /dev/md0 mklabel gpt
                parted /dev/md0 mkpart primary ext4 0% 20%
                parted /dev/md0 mkpart primary ext4 20% 40%
                parted /dev/md0 mkpart primary ext4 40% 60%
                parted /dev/md0 mkpart primary ext4 60% 80%
                parted /dev/md0 mkpart primary ext4 80% 100%
                mkdir -p /raid/part{1,2,3,4,5}
                for i in $(seq 1 5); do mkfs.ext4 /dev/md0p$i; done
        SHELL

        box.vm.provision "shell", run: "always", inline: <<-SHELL
                for i in $(seq 1 5); do mount /dev/md0p$i /raid/part$i; done
        SHELL
```
