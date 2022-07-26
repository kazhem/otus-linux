
- [Практика](#практика)
  - [Подготовка](#подготовка)
    - [Запуск и подключение к виртуалке](#запуск-и-подключение-к-виртуалке)
    - [Посмотреть доступные устройства](#посмотреть-доступные-устройства)
  - [Разметка диска](#разметка-диска)
    - [Создание файловой системы](#создание-файловой-системы)
  - [Изменение размера LVM](#изменение-размера-lvm)
    - [Расширение](#расширение)
    - [Уменьшение LV](#уменьшение-lv)
  - [LVM Snapshot](#lvm-snapshot)
    - [Создание](#создание)
    - [Восстановление](#восстановление)
  - [LVM Mirroring](#lvm-mirroring)
- [Домашнее Задание](#домашнее-задание)
  - [Задание](#задание)
  - [Подготовка стенда](#подготовка-стенда)
  - [Уменьшение топа под корень / до 8Gb](#уменьшение-топа-под-корень--до-8gb)
    - [Создание LV](#создание-lv)
    - [Перенос данных](#перенос-данных)
    - [Перенос boot на новый root](#перенос-boot-на-новый-root)
    - [Уменьшение размера старого диска](#уменьшение-размера-старого-диска)
  - [Выделение тома под /var в зеркало](#выделение-тома-под-var-в-зеркало)
  - [Снапшоты home](#снапшоты-home)
    - [Создание volume для /home](#создание-volume-для-home)
    - [Тестирование создания тома для снапшотов](#тестирование-создания-тома-для-снапшотов)

Изначальный [стенд](https://gitlab.com/otus_linux/stands-03-lvm/-/tree/master/)

# Практика
## Подготовка
### Запуск и подключение к виртуалке
```
vagrunt up
vagrant ssh
```
Необходимо было убрать box_version и поменять ip адрес виртуалки из доступных, поправить место хранения дисков
### Посмотреть доступные устройства

```
[vagrant@lvm ~]$ lsblk
NAME   MAJ:MIN RM SIZE RO TYPE MOUNTPOINT
sda      8:0    0  40G  0 disk
└─sda1   8:1    0  40G  0 part /
sdb      8:16   0  10G  0 disk
sdc      8:32   0   2G  0 disk
sdd      8:48   0   1G  0 disk
sde      8:64   0   1G  0 disk
```
```
[root@lvm vagrant]# lvmdiskscan
  /dev/sda1 [     <40.00 GiB]
  /dev/sdb  [      10.00 GiB]
  /dev/sdc  [       2.00 GiB]
  /dev/sdd  [       1.00 GiB]
  /dev/sde  [       1.00 GiB]
  4 disks
  1 partition
  0 LVM physical volume whole disks
  0 LVM physical volumes
```
На выделенных дисках будем экспериментировать. Диски sdb, sdc будем использовать
для базовых вещей и снапшотов. На дисках sdd,sde создадим lvm mirror

## Разметка диска
Для начала разметим диск для будущего использования LVM - создадим PV
```
[root@lvm vagrant]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.
```
Затем можно создавать первый уровень абстракции - VG:
```
[root@lvm vagrant]# vgcreate otus /dev/sdb
  Volume group "otus" successfully created
```
И в итоге создать Logical Volume (далее - LV):
```
[root@lvm vagrant]# lvcreate -l+80%FREE -n test otus
  Logical volume "test" created.
```
Посмотреть информацию о только что созданном Volume Group:

```
[root@lvm vagrant]# vgdisplay otus
  --- Volume group ---
  VG Name               otus
  System ID
  Format                lvm2
  Metadata Areas        1
  Metadata Sequence No  2
  VG Access             read/write
  VG Status             resizable
  MAX LV                0
  Cur LV                1
  Open LV               0
  Max PV                0
  Cur PV                1
  Act PV                1
  VG Size               <10.00 GiB
  PE Size               4.00 MiB
  Total PE              2559
  Alloc PE / Size       2047 / <8.00 GiB
  Free  PE / Size       512 / 2.00 GiB
  VG UUID               u8cGHJ-1w2z-c3Gm-YvJ1-c7Pc-3Vzv-dGosz0

[root@lvm vagrant]# vgdisplay  -v otus | grep "PV Name"
  PV Name               /dev/sdb
```
Посмотреть информацию о LV
```
[root@lvm vagrant]# lvdisplay /dev/otus/test
  --- Logical volume ---
  LV Path                /dev/otus/test
  LV Name                test
  VG Name                otus
  LV UUID                mo29gA-awt8-U2eQ-jKrl-00e0-0LHV-IpNrN8
  LV Write Access        read/write
  LV Creation host, time lvm, 2022-07-20 17:55:46 +0000
  LV Status              available
  # open                 0
  LV Size                <8.00 GiB
  Current LE             2047
  Segments               1
  Allocation             inherit
  Read ahead sectors     auto
  - currently set to     8192
  Block device           253:0
```
В сжатом виде информацию можно получить командами vgs и lvs:
```
[root@lvm vagrant]# vgs
  VG   #PV #LV #SN Attr   VSize   VFree
  otus   1   1   0 wz--n- <10.00g 2.00g
[root@lvm vagrant]# lvs
  LV   VG   Attr       LSize  Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  test otus -wi-a----- <8.00g
```
Мы можем создать еще один LV из свободного места. На этот раз создадим не
экстентами, а абсолютным значением в мегабайтах:
```
[root@lvm vagrant]#  lvcreate -L100M -n small otus
  Logical volume "small" created.

[root@lvm vagrant]# lvs
  LV    VG   Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  small otus -wi-a----- 100.00m
  test  otus -wi-a-----  <8.00g
```
### Создание файловой системы
Создадим файловую систему (ФС) ext4 на LV test
```shell
mkfs.ext4 /dev/otus/test
```
<details><summary>log</summary>

```log
mke2fs 1.42.9 (28-Dec-2013)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
524288 inodes, 2096128 blocks
104806 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=2147483648
64 block groups
32768 blocks per group, 32768 fragments per group
8192 inodes per group
Superblock backups stored on blocks:
        32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632

Allocating group tables: done
Writing inode tables: done
Creating journal (32768 blocks): done
Writing superblocks and filesystem accounting information: done
```
</details>


Смонтируем ФС
```
[root@lvm vagrant]# mkdir /data
[root@lvm vagrant]# mount /dev/otus/test /data/
[root@lvm vagrant]# mount | grep /data
/dev/mapper/otus-test on /data type ext4 (rw,relatime,seclabel,data=ordered)
```

## Изменение размера LVM
### Расширение
Допустим перед нами встала проблема нехватки свободного места в директории `/data`. Мы
можем расширить файловую систему на LV `/dev/otus/test` за счет нового блочного устройства
`/dev/sdc`
Для начала так же необходимо создать PV:
```
[root@lvm vagrant]# pvcreate /dev/sdc
  Physical volume "/dev/sdc" successfully created.
```
Далее необходимо расширить VG добавив в него этот диск
```
[root@lvm vagrant]# vgextend otus /dev/sdc
  Volume group "otus" successfully extended
```
Убедимся что новый диск присутствует в новой VG:
```
[root@lvm vagrant]# vgdisplay -v otus | grep 'PV Name'
  PV Name               /dev/sdb
  PV Name               /dev/sdc
```
И что места в VG прибавилось:
```
[root@lvm vagrant]# vgs
  VG   #PV #LV #SN Attr   VSize  VFree
  otus   2   2   0 wz--n- 11.99g <3.90g
```

Сымитируем занятое место с помощью команды dd для большей наглядности:
```
[root@lvm vagrant]#  dd if=/dev/zero of=/data/test.log bs=1M count=8000 status=progress
8024752128 bytes (8.0 GB) copied, 10.029913 s, 800 MB/s
dd: error writing ‘/data/test.log’: No space left on device
7880+0 records in
7879+0 records out
8262189056 bytes (8.3 GB) copied, 10.378 s, 796 MB/s
```

```
[root@lvm vagrant]# df -h
Filesystem             Size  Used Avail Use% Mounted on
devtmpfs               111M     0  111M   0% /dev
tmpfs                  118M     0  118M   0% /dev/shm
tmpfs                  118M  4.5M  113M   4% /run
tmpfs                  118M     0  118M   0% /sys/fs/cgroup
/dev/sda1               40G  3.6G   37G   9% /
tmpfs                   24M     0   24M   0% /run/user/1000
/dev/mapper/otus-test  7.8G  7.8G     0 100% /data
```

Увеличиваем LV за счет появившегося свободного места. Возьмем не все место - это для того,
чтобы осталось место для демонстрации снапшотов:
```
[root@lvm vagrant]#  lvextend -l+80%FREE /dev/otus/test
  Size of logical volume otus/test changed from <8.00 GiB (2047 extents) to <11.12 GiB (2846 extents).
  Logical volume otus/test successfully resized.
```
```
[root@lvm vagrant]# lvs /dev/otus/test
  LV   VG   Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  test otus -wi-ao---- <11.12g
```
Но файловая система при этом осталась прежнего размера:
```
Filesystem            Type  Size  Used Avail Use% Mounted on
/dev/mapper/otus-test ext4  7.8G  7.8G     0 100% /data
```
Произведем resize файловой системы:
```
[root@lvm vagrant]# resize2fs /dev/otus/test
resize2fs 1.42.9 (28-Dec-2013)
Filesystem at /dev/otus/test is mounted on /data; on-line resizing required
old_desc_blocks = 1, new_desc_blocks = 2
The filesystem on /dev/otus/test is now 2914304 blocks long.
```
```
[root@lvm vagrant]# df -Th /data
Filesystem            Type  Size  Used Avail Use% Mounted on
/dev/mapper/otus-test ext4   11G  7.8G  2.6G  76% /data
```

### Уменьшение LV
Допустим Вы забыли оставить место на снапшоты. Можно уменьшить существующий LV с
помощью команды lvreduce, но перед этим необходимо отмонтировать файловую систему,
проверить её на ошибки и уменьшить ее размер:
```
[root@lvm vagrant]# umount /data

[root@lvm vagrant]# e2fsck -fy /dev/otus/test
e2fsck 1.42.9 (28-Dec-2013)
Pass 1: Checking inodes, blocks, and sizes
Pass 2: Checking directory structure
Pass 3: Checking directory connectivity
Pass 4: Checking reference counts
Pass 5: Checking group summary information
/dev/otus/test: 12/729088 files (0.0% non-contiguous), 2105907/2914304 blocks

[root@lvm vagrant]# resize2fs /dev/otus/test 10G
resize2fs 1.42.9 (28-Dec-2013)
Resizing the filesystem on /dev/otus/test to 2621440 (4k) blocks.
The filesystem on /dev/otus/test is now 2621440 blocks long.

[root@lvm vagrant]# lvreduce /dev/otus/test -L 10G
  WARNING: Reducing active logical volume to 10.00 GiB.
  THIS MAY DESTROY YOUR DATA (filesystem etc.)
Do you really want to reduce otus/test? [y/n]: y
  Size of logical volume otus/test changed from <11.12 GiB (2846 extents) to 10.00 GiB (2560 extents).
  Logical volume otus/test successfully resized.
```

```
[root@lvm vagrant]# mount /dev/otus/test /data/
[root@lvm vagrant]# df -Th /data
Filesystem            Type  Size  Used Avail Use% Mounted on
/dev/mapper/otus-test ext4  9.8G  7.8G  1.6G  84% /data
```
```
[root@lvm vagrant]# vgs
  VG   #PV #LV #SN Attr   VSize  VFree
  otus   2   2   0 wz--n- 11.99g 1.89g
[root@lvm vagrant]# lvs
  LV    VG   Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  small otus -wi-a----- 100.00m
  test  otus -wi-ao----  10.00g
```
## LVM Snapshot
### Создание
Снапшот создается командой lvcreate, только с флагом -s, который указывает на то, что это
снимок:
```
[root@lvm vagrant]# lvcreate -L 500M -s -n test-snap /dev/otus/test
  Logical volume "test-snap" created.

[root@lvm vagrant]# vgs -o +lv_size,lv_name | grep tes
otus   2   3   1 wz--n- 11.99g <1.41g  10.00g test
otus   2   3   1 wz--n- 11.99g <1.41g 500.00m test-snap
```
Команда lsblk, например, нам наглядно покажет, что произошло:
```
[root@lvm vagrant]# lsblk
NAME                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                     8:0    0   40G  0 disk
└─sda1                  8:1    0   40G  0 part /
sdb                     8:16   0   10G  0 disk
├─otus-small          253:1    0  100M  0 lvm
└─otus-test-real      253:2    0   10G  0 lvm
  ├─otus-test         253:0    0   10G  0 lvm  /data
  └─otus-test--snap   253:4    0   10G  0 lvm
sdc                     8:32   0    2G  0 disk
├─otus-test-real      253:2    0   10G  0 lvm   <------- Оригинальный LV
│ ├─otus-test         253:0    0   10G  0 lvm  /data
│ └─otus-test--snap   253:4    0   10G  0 lvm   <------- Снапшот
└─otus-test--snap-cow 253:3    0  500M  0 lvm   <------- Copy On Write. Сюда пишутся все изменения
  └─otus-test--snap   253:4    0   10G  0 lvm
sdd                     8:48   0    1G  0 disk
sde                     8:64   0    1G  0 disk
```
Снапшот можно смонтировать как и любой другой LV:
```
[root@lvm vagrant]# mkdir /data-snap
[root@lvm vagrant]# mount /dev/otus/test-snap /data-snap

[root@lvm vagrant]# ll /data-snap/
total 8068564
drwx------. 2 root root      16384 Jul 20 18:57 lost+found
-rw-r--r--. 1 root root 8262189056 Jul 20 19:17 test.log

[root@lvm vagrant]# ll /data
total 8068564
drwx------. 2 root root      16384 Jul 20 18:57 lost+found
-rw-r--r--. 1 root root 8262189056 Jul 20 19:17 test.log

[root@lvm vagrant]# umount /data-snap
```
### Восстановление
Можно также восстановить предыдущее состояние. “Откатиться” на снапшот. Для этого
сначала для большей наглядности удалим наш log файл:
```shell
[root@lvm vagrant]# rm /data/test.log
rm: remove regular file ‘/data/test.log’? y
[root@lvm vagrant]# ll /data
total 16
drwx------. 2 root root 16384 Jul 20 18:57 lost+found
```
```
[root@lvm vagrant]# umount /data
[root@lvm vagrant]# lvconvert --merge /dev/otus/test-snap
  Merging of volume otus/test-snap started.
  otus/test: Merged: 100.00%

[root@lvm vagrant]# mount /dev/otus/test /data
[root@lvm vagrant]# ll /data
total 8068564
drwx------. 2 root root      16384 Jul 20 18:57 lost+found
-rw-r--r--. 1 root root 8262189056 Jul 20 19:17 test.log
```

## LVM Mirroring
Создадим PV
```
root@lvm vagrant]# pvcreate /dev/sd{d,e}
  Physical volume "/dev/sdd" successfully created.
  Physical volume "/dev/sde" successfully created.
```
Создадим VG vg0 из двух дисков:
```
[root@lvm vagrant]# vgcreate vg0 /dev/sd{d,e}
  Volume group "vg0" successfully created
```
Создадим LV с мирорингом:
```
[root@lvm vagrant]# lvcreate -l+80%FREE -m1 -n mirror vg0
  Logical volume "mirror" created.

[root@lvm vagrant]# lsblk
NAME                  MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                     8:0    0   40G  0 disk
└─sda1                  8:1    0   40G  0 part /
sdb                     8:16   0   10G  0 disk
├─otus-test           253:0    0   10G  0 lvm  /data
└─otus-small          253:1    0  100M  0 lvm
sdc                     8:32   0    2G  0 disk
└─otus-test           253:0    0   10G  0 lvm  /data
sdd                     8:48   0    1G  0 disk
├─vg0-mirror_rmeta_0  253:2    0    4M  0 lvm
│ └─vg0-mirror        253:6    0  816M  0 lvm
└─vg0-mirror_rimage_0 253:3    0  816M  0 lvm
  └─vg0-mirror        253:6    0  816M  0 lvm
sde                     8:64   0    1G  0 disk
├─vg0-mirror_rmeta_1  253:4    0    4M  0 lvm
│ └─vg0-mirror        253:6    0  816M  0 lvm
└─vg0-mirror_rimage_1 253:5    0  816M  0 lvm
  └─vg0-mirror        253:6    0  816M  0 lvm

[root@lvm vagrant]# lvs
  LV     VG   Attr       LSize   Pool Origin Data%  Meta%  Move Log Cpy%Sync Convert
  small  otus -wi-a----- 100.00m
  test   otus -wi-ao----  10.00g
  mirror vg0  rwi-a-r--- 816.00m                                    100.00
```


# Домашнее Задание
## Задание

1. Уменьшить том под / до 8G
1. Выделить том под /home
1. Выделить том под /var - сделать в mirror
1. /home - сделать том для снапшотов
1. Прописать монтирование в fstab. Попробовать с разными опциями и разными файловыми системами ( на выбор)

Работа со снапшотами:
- сгенерить файлы в /home/
- снять снапшот
- удалить часть файлов
- восстановится со снапшота
- залоггировать работу можно с помощья утилиты script
- *на нашей куче дисков попробовать поставить `btrfs`/`zfs` с кешем, снапшотами - разметить здесь каталог `/opt`


## Подготовка стенда
Пересоздадим виртуалку и добавим установку `xfsdump` в vagrantfile
```
vagrant destroy
vagrant up
vagrant ssh
```

**Важно**: использовать `config.vm.box_version = "1804.02"` - для последней 2004.хх корень не на lvm и будут расхождения

```
[root@lvm vagrant]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol00 253:0    0 37.5G  0 lvm  /
  └─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
sdb                       8:16   0   10G  0 disk
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

## Уменьшение топа под корень / до 8Gb
### Создание LV
Изначально:
```
[root@lvm vagrant]# df -hT /
Filesystem     Type  Size  Used Avail Use% Mounted on
/dev/mapper/VolGroup00-LogVol00 xfs    38G  830M   37G   3% /
```
Создадим lv:
```
[root@lvm vagrant]# pvcreate /dev/sdb
  Physical volume "/dev/sdb" successfully created.

[root@lvm vagrant]# vgcreate vg_root /dev/sdb
  Volume group "vg_root" successfully created

[root@lvm vagrant]# lvcreate -n lv_root -l +100%FREE /dev/vg_root
  Logical volume "lv_root" created
```

Создадим там файловую систему для переноса корня и смонтируем
```
[root@lvm vagrant]# mount | grep sda
/dev/sda2 on /boot type xfs (rw,relatime,seclabel,attr2,inode64,noquota)

[root@lvm vagrant]# mkfs.xfs /dev/vg_root/lv_root
meta-data=/dev/vg_root/lv_root   isize=512    agcount=4, agsize=655104 blks
         =                       sectsz=512   attr=2, projid32bit=1
         =                       crc=1        finobt=0, sparse=0
data     =                       bsize=4096   blocks=2620416, imaxpct=25
         =                       sunit=0      swidth=0 blks
naming   =version 2              bsize=4096   ascii-ci=0 ftype=1
log      =internal log           bsize=4096   blocks=2560, version=2
         =                       sectsz=512   sunit=0 blks, lazy-count=1
realtime =none                   extsz=4096   blocks=0, rtextents=0

[root@lvm vagrant]#  mount /dev/vg_root/lv_root /mnt
```

### Перенос данных
Перенесем данные с `/` новый вольюм `/mnt`:
```
[root@lvm vagrant]# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
```
где
- `xfsdump -J` Inhibits the normal update of the inventory. This is useful when the media being dumped to will be discarded or overwritten.
- `xfsrestore -J` Inhibits inventory update when on-media session inventory encountered during restore. `xfsrestore` opportunistically updates the online inventory when it encounters an on-media session inventory, but only if run with an effective user id of root and only if this option is not given.

<details><summary>log</summary>

```log
[root@lvm vagrant]# xfsdump -J - /dev/VolGroup00/LogVol00 | xfsrestore -J - /mnt
xfsrestore: using file dump (drive_simple) strategy
xfsrestore: version 3.1.7 (dump format 3.0)
xfsdump: using file dump (drive_simple) strategy
xfsdump: version 3.1.7 (dump format 3.0)
xfsdump: level 0 dump of lvm:/
xfsdump: dump date: Wed Jul 20 20:24:38 2022
xfsdump: session id: 9adf3f6b-e71f-49c8-8a27-61f7f6e41d40
xfsdump: session label: ""
xfsrestore: searching media for dump
xfsdump: ino map phase 1: constructing initial dump list
xfsdump: ino map phase 2: skipping (no pruning necessary)
xfsdump: ino map phase 3: skipping (only one dump stream)
xfsdump: ino map construction complete
xfsdump: estimated dump size: 3316467840 bytes
xfsdump: creating dump session media file 0 (media 0, file 0)
xfsdump: dumping ino map
xfsdump: dumping directories
xfsrestore: examining media file 0
xfsrestore: dump description:
xfsrestore: hostname: lvm
xfsrestore: mount point: /
xfsrestore: volume: /dev/sda1
xfsrestore: session time: Wed Jul 20 20:24:38 2022
xfsrestore: level: 0
xfsrestore: session label: ""
xfsrestore: media label: ""
xfsrestore: file system id: 1c419d6c-5064-4a2b-953c-05b2c67edb15
xfsrestore: session id: 9adf3f6b-e71f-49c8-8a27-61f7f6e41d40
xfsrestore: media id: a1814122-1340-481e-8597-d35b9d09e074
xfsrestore: searching media for directory dump
xfsrestore: reading directories
xfsdump: dumping non-directory files
xfsrestore: 2987 directories and 32111 entries processed
xfsrestore: directory post-processing
xfsrestore: restoring non-directory files
xfsdump: media file size 3279102120 bytes
xfsdump: dump size (non-dir files) : 3260464832 bytes
xfsdump: dump complete: 22 seconds elapsed
xfsdump: Dump Status: SUCCESS
xfsrestore: restore complete: 22 seconds elapsed
xfsrestore: Restore Status: SUCCESS
```
</details>

```
[root@lvm vagrant]# ls -la /mnt
total 2097164
drwxr-xr-x. 18 root    root           255 Jul 20 20:25 .
dr-xr-xr-x. 18 root    root           255 Jul 20 20:09 ..
lrwxrwxrwx.  1 root    root             7 Jul 20 20:24 bin -> usr/bin
dr-xr-xr-x.  4 root    root           275 Apr 30  2020 boot
drwxr-xr-x.  2 root    root             6 Apr 30  2020 dev
drwxr-xr-x. 81 root    root          8192 Jul 20 20:09 etc
drwxr-xr-x.  3 root    root            21 Apr 30  2020 home
lrwxrwxrwx.  1 root    root             7 Jul 20 20:24 lib -> usr/lib
lrwxrwxrwx.  1 root    root             9 Jul 20 20:24 lib64 -> usr/lib64
drwxr-xr-x.  2 root    root             6 Apr 11  2018 media
drwxr-xr-x.  2 root    root             6 Apr 11  2018 mnt
drwxr-xr-x.  2 root    root             6 Apr 11  2018 opt
drwxr-xr-x.  2 root    root             6 Apr 30  2020 proc
dr-xr-x---.  3 root    root           149 Jul 20 20:09 root
drwxr-xr-x.  2 root    root             6 Apr 30  2020 run
lrwxrwxrwx.  1 root    root             8 Jul 20 20:24 sbin -> usr/sbin
drwxr-xr-x.  2 root    root             6 Apr 11  2018 srv
-rw-------.  1 root    root    2147483648 Apr 30  2020 swapfile
drwxr-xr-x.  2 root    root             6 Apr 30  2020 sys
drwxrwxrwt.  8 root    root           193 Jul 20 20:24 tmp
drwxr-xr-x. 13 root    root           155 Apr 30  2020 usr
drwxr-xr-x.  2 vagrant vagrant         86 Jul 20 20:00 vagrant
drwxr-xr-x. 18 root    root           254 Jul 20 20:09 var
```

### Перенос boot на новый root
Затем переконфигурируем `grub` для того, чтобы при старте перейти в новый `/`
Сымитируем текущий root -> сделаем в него [chroot](https://wiki.archlinux.org/title/Chroot_(Русский)) и обновим `grub`:

```
[root@lvm vagrant]# for i in /proc/ /sys/ /dev/ /run/ /boot/; do sudo mount --bind $i /mnt/$i; done

[root@lvm vagrant]# chroot /mnt
```
Обновим grub:
```
[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
Generating grub configuration file ...
Found linux image: /boot/vmlinuz-3.10.0-1127.el7.x86_64
Found initrd image: /boot/initramfs-3.10.0-1127.el7.x86_64.img
done
```
Обновим образ [initrd](https://ru.wikipedia.org/wiki/Initrd). Что это такое и зачем нужно вы узнаете из след. лекции
```
[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
```
<details><summary>log</summary>

```log
Executing: /sbin/dracut -v initramfs-3.10.0-1127.el7.x86_64.img 3.10.0-1127.el7.x86_64 --force
dracut module 'busybox' will not be installed, because command 'busybox' could not be found!
dracut module 'plymouth' will not be installed, because command 'plymouthd' could not be found!
dracut module 'plymouth' will not be installed, because command 'plymouth' could not be found!
dracut module 'crypt' will not be installed, because command 'cryptsetup' could not be found!
dracut module 'dmraid' will not be installed, because command 'dmraid' could not be found!
dracut module 'dmsquash-live-ntfs' will not be installed, because command 'ntfs-3g' could not be found!
dracut module 'multipath' will not be installed, because command 'multipath' could not be found!
dracut module 'busybox' will not be installed, because command 'busybox' could not be found!
dracut module 'crypt' will not be installed, because command 'cryptsetup' could not be found!
dracut module 'dmraid' will not be installed, because command 'dmraid' could not be found!
dracut module 'dmsquash-live-ntfs' will not be installed, because command 'ntfs-3g' could not be found!
dracut module 'multipath' will not be installed, because command 'multipath' could not be found!
*** Including module: bash ***
*** Including module: nss-softokn ***
*** Including module: i18n ***
*** Including module: dm ***
Skipping udev rule: 64-device-mapper.rules
Skipping udev rule: 60-persistent-storage-dm.rules
Skipping udev rule: 55-dm.rules
*** Including module: kernel-modules ***
Omitting driver floppy
*** Including module: lvm ***
Skipping udev rule: 64-device-mapper.rules
Skipping udev rule: 56-lvm.rules
Skipping udev rule: 60-persistent-storage-lvm.rules
*** Including module: qemu ***
*** Including module: rootfs-block ***
*** Including module: terminfo ***
*** Including module: udev-rules ***
Skipping udev rule: 40-redhat-cpu-hotplug.rules
Skipping udev rule: 91-permissions.rules
*** Including module: biosdevname ***
*** Including module: systemd ***
*** Including module: usrmount ***
*** Including module: base ***
*** Including module: fs-lib ***
*** Including module: shutdown ***
*** Including modules done ***
*** Installing kernel module dependencies and firmware ***
*** Installing kernel module dependencies and firmware done ***
*** Resolving executable dependencies ***
*** Resolving executable dependencies done***
*** Hardlinking files ***
*** Hardlinking files done ***
*** Stripping files ***
*** Stripping files done ***
*** Generating early-microcode cpio image contents ***
*** No early-microcode cpio image needed ***
*** Store current command line parameters ***
*** Creating image file ***
*** Creating image file done ***
*** Creating initramfs image file '/boot/initramfs-3.10.0-1127.el7.x86_64.img' done ***
```
</details>

Ну и для того, чтобы при загрузке был смонтирован нужны root нужно в файле
`/boot/grub2/grub.cfg` заменить `rd.lvm.lv=VolGroup00/LogVol00` на `rd.lvm.lv=vg_root/lv_root`
и перезапустить VM
```shell
vi /boot/grub2/grub.cfg
```

Проверяем что после перезапуска корень на другом устройстве:
```
[root@lvm vagrant]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0 37.5G  0 lvm
sdb                       8:16   0   10G  0 disk
└─vg_root-lv_root       253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```

### Уменьшение размера старого диска
Теперь нам нужно изменить размер старой VG и вернуть на него рут.
Для этого удаляем  старый LV размеров в 40G и создаем новый на 6G
```
[root@lvm vagrant]# lvremove /dev/VolGroup00/LogVol00
Do you really want to remove active logical volume VolGroup00/LogVol00? [y/n]: y
  Logical volume "LogVol00" successfully removed
```

```
[root@lvm vagrant]# lvcreate -n VolGroup00/LogVol00 -L 6G /dev/VolGroup00
WARNING: xfs signature detected on /dev/VolGroup00/LogVol00 at offset 0. Wipe it? [y/n]: y
  Wiping xfs signature on /dev/VolGroup00/LogVol00.
  Logical volume "LogVol00" created.
```
```
[root@lvm vagrant]# lsblk
NAME                    MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                       8:0    0   40G  0 disk
├─sda1                    8:1    0    1M  0 part
├─sda2                    8:2    0    1G  0 part /boot
└─sda3                    8:3    0   39G  0 part
  ├─VolGroup00-LogVol01 253:1    0  1.5G  0 lvm  [SWAP]
  └─VolGroup00-LogVol00 253:2    0    6G  0 lvm
sdb                       8:16   0   10G  0 disk
└─vg_root-lv_root       253:0    0   10G  0 lvm  /
sdc                       8:32   0    2G  0 disk
sdd                       8:48   0    1G  0 disk
sde                       8:64   0    1G  0 disk
```
```
[root@lvm vagrant]# mkfs.xfs /dev/VolGroup00/LogVol00
[root@lvm vagrant]# mount /dev/VolGroup00/LogVol00 /mnt
```

Скопируем данные обратно:
```
sudo xfsdump -J - /dev/vg_root/lv_root | sudo xfsrestore -J - /mnt
```
Так же как в первый раз переконфигурируем grub, за исключением правки /etc/grub2/grub.cfg и перегенерим initrd:
```
[root@lvm vagrant]#  for i in /proc/ /sys/ /dev/ /run/ /boot/; do mount --bind $i /mnt/$i; done
[root@lvm vagrant]# chroot /mnt/
[root@lvm /]# grub2-mkconfig -o /boot/grub2/grub.cfg
[root@lvm /]# cd /boot ; for i in `ls initramfs-*img`; do dracut -v $i `echo $i|sed "s/initramfs-//g; s/.img//g"` --force; done
```

Пока не перезагружаемся и не выходим из под chroot - мы можем заодно перенести /var на зеркало

## Выделение тома под /var в зеркало

```
[root@lvm boot]# pvcreate /dev/sdc /dev/sdd
[root@lvm boot]# vgcreate vg_var /dev/sdc /dev/sdd
[root@lvm boot]# lvcreate -L 950M -m1 -n lv_var vg_var
[root@lvm boot]# mkfs.ext4 /dev/vg_var/lv_var
[root@lvm boot]# mount /dev/vg_var/lv_var /mnt
[root@lvm boot]# sudo mkdir /newvar
[root@lvm boot]# mount /dev/vg_var/lv_var /newvar/
```
Скопируем данные из `/var` в `/newwar`
```
rsync -avHPSAX /var/ /newvar
```

Забекапим старый `/var`
```
[root@lvm /]# mkdir /tmp/oldvar && mv /var/* /tmp/oldvar
```
Ну и монтируем новый var в каталог `/var`:
```
[root@lvm /]# mount /dev/vg_var/lv_var /var
```
Правим fstab для автоматического монтирования `/var`:
```
[root@lvm /]# echo "`sudo blkid | grep var: | awk '{print $2}'` /var ext4 defaults 0 0" | sudo tee --append /etc/fstab
UUID="17a88688-9f59-474e-8cf1-7fc9a6199679" /var ext4 defaults 0 0
```

**Перезапуск**
Проверяем результат:
```
[vagrant@lvm ~]$ lsblk
NAME                     MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda                        8:0    0   40G  0 disk
├─sda1                     8:1    0    1M  0 part
├─sda2                     8:2    0    1G  0 part /boot
└─sda3                     8:3    0   39G  0 part
  ├─VolGroup00-LogVol00  253:0    0    6G  0 lvm  /
  └─VolGroup00-LogVol01  253:1    0  1.5G  0 lvm  [SWAP]
sdb                        8:16   0   10G  0 disk
└─vg_root-lv_root        253:2    0   10G  0 lvm
sdc                        8:32   0    2G  0 disk
├─vg_var-lv_var_rmeta_0  253:3    0    4M  0 lvm
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_0 253:4    0  952M  0 lvm
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sdd                        8:48   0    1G  0 disk
├─vg_var-lv_var_rmeta_1  253:5    0    4M  0 lvm
│ └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
└─vg_var-lv_var_rimage_1 253:6    0  952M  0 lvm
  └─vg_var-lv_var        253:7    0  952M  0 lvm  /var
sde                        8:64   0    1G  0 disk
```
После чего можно успешно перезагружаться в новый (уменьшенный root) и удалять
временную Volume Group:
```shell
[root@lvm vagrant]# lvremove /dev/vg_root/lv_root
Do you really want to remove active logical volume vg_root/lv_root? [y/n]: y
  Logical volume "lv_root" successfully removed

[root@lvm vagrant]# vgremove /dev/vg_root
  Volume group "vg_root" successfully removed

[root@lvm vagrant]# pvremove /dev/sdb
  Labels on physical volume "/dev/sdb" successfully wiped.
```

## Снапшоты home

### Создание volume для /home
Так же, как для /var
```
[root@lvm vagrant]# lvcreate -n LogVol_Home -L 2G /dev/VolGroup00
[root@lvm vagrant]# mkfs.xfs /dev/VolGroup00/LogVol_Home
[root@lvm vagrant]# mount /dev/VolGroup00/LogVol_Home /mnt/
[root@lvm vagrant]# cp -aR /home/* /mnt/
[root@lvm vagrant]# rm -rf /home/*
[root@lvm vagrant]# umount /mnt
[root@lvm vagrant]# mount /dev/VolGroup00/LogVol_Home /home/
```
Обновим fstab
```
[root@lvm vagrant]# echo "`sudo blkid | grep Home: | awk '{print $2}'` /home xfs defaults 0 0" | sudo tee --append /etc/fstab
UUID="4ccb7d3d-8e66-42e2-a424-f87faf1f558d" /home xfs defaults 0 0
```
### Тестирование создания тома для снапшотов

Сгенерируем файлы в /home
```
[root@lvm vagrant]# touch /home/file{1..20}
[root@lvm vagrant]# ls -la /home/
total 0
drwxr-xr-x.  3 root    root    292 Jul 26 18:59 .
drwxr-xr-x. 19 root    root    253 Jul 26 18:40 ..
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file1
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file10
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file11
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file12
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file13
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file14
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file15
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file16
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file17
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file18
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file19
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file2
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file20
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file3
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file4
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file5
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file6
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file7
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file8
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file9
```
Снимем снапшот
```
[root@lvm vagrant]# lvcreate -L 100MB -s -n home_snap /dev/VolGroup00/LogVol_Home
  Rounding up size to full physical extent 128.00 MiB
  Logical volume "home_snap" created.
```
Удалим часть файлов:
```
[root@lvm vagrant]# rm -f /home/file{11..20}
```
Восстановимся из снапшота:
```
[root@lvm vagrant]# umount /home
[root@lvm vagrant]# lvconvert --merge /dev/VolGroup00/home_snap
  Merging of volume VolGroup00/home_snap started.
  VolGroup00/LogVol_Home: Merged: 100.00%
[root@lvm vagrant]# mount /home
```

Проверяем:
```
[root@lvm vagrant]# ls -la /home/
total 0
drwxr-xr-x.  3 root    root    292 Jul 26 18:59 .
drwxr-xr-x. 19 root    root    253 Jul 26 18:40 ..
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file1
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file10
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file11
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file12
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file13
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file14
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file15
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file16
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file17
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file18
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file19
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file2
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file20
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file3
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file4
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file5
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file6
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file7
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file8
-rw-r--r--.  1 root    root      0 Jul 26 18:59 file9
```
Основное ДЗ сделано
