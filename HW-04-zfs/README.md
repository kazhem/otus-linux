# Стенд с Vagrant c ZFS
- [Стенд с Vagrant c ZFS](#стенд-с-vagrant-c-zfs)
- [Домашние задание](#домашние-задание)
  - [Определение алгоритма с наилучшим сжатием](#определение-алгоритма-с-наилучшим-сжатием)
    - [Добавление пулов zfs](#добавление-пулов-zfs)
    - [Добавление сжатия на пулы](#добавление-сжатия-на-пулы)
    - [Сравнение алгоритмов сжатия](#сравнение-алгоритмов-сжатия)
  - [Определение настроек пула](#определение-настроек-пула)
  - [Работа со снапшотом, поиск сообщения от преподавателя](#работа-со-снапшотом-поиск-сообщения-от-преподавателя)

# Домашние задание
## Определение алгоритма с наилучшим сжатием
Смотрим список всех дисков, которые есть в виртуальной машине:
```
[vagrant@server ~]$ lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   64G  0 disk
|-sda1   8:1    0  2.1G  0 part [SWAP]
`-sda2   8:2    0 61.9G  0 part /
sdb      8:16   0    1G  0 disk
sdc      8:32   0    1G  0 disk
sdd      8:48   0    1G  0 disk
sde      8:64   0    1G  0 disk
sdf      8:80   0    1G  0 disk
sdg      8:96   0    1G  0 disk
sdh      8:112  0    1G  0 disk
sdi      8:128  0    1G  0 disk
```
Активировать zfs в ядре:
```
/sbin/modprobe zfs
```
### Добавление пулов zfs
Создаём 4 пула из двух дисков в режиме RAID 1:
```
[root@server vagrant]# zpool create otus1 mirror /dev/sdb /dev/sdc
[root@server vagrant]# zpool create otus2 mirror /dev/sdd /dev/sde
[root@server vagrant]# zpool create otus3 mirror /dev/sdf /dev/sdg
[root@server vagrant]# zpool create otus4 mirror /dev/sdh /dev/sdi
```
```
[root@server vagrant]# lsblk
NAME   MAJ:MIN RM  SIZE RO TYPE MOUNTPOINT
sda      8:0    0   64G  0 disk
|-sda1   8:1    0  2.1G  0 part [SWAP]
`-sda2   8:2    0 61.9G  0 part /
sdb      8:16   0    1G  0 disk
|-sdb1   8:17   0 1014M  0 part
`-sdb9   8:25   0    8M  0 part
sdc      8:32   0    1G  0 disk
|-sdc1   8:33   0 1014M  0 part
`-sdc9   8:41   0    8M  0 part
sdd      8:48   0    1G  0 disk
|-sdd1   8:49   0 1014M  0 part
`-sdd9   8:57   0    8M  0 part
sde      8:64   0    1G  0 disk
|-sde1   8:65   0 1014M  0 part
`-sde9   8:73   0    8M  0 part
sdf      8:80   0    1G  0 disk
|-sdf1   8:81   0 1014M  0 part
`-sdf9   8:89   0    8M  0 part
sdg      8:96   0    1G  0 disk
|-sdg1   8:97   0 1014M  0 part
`-sdg9   8:105  0    8M  0 part
sdh      8:112  0    1G  0 disk
|-sdh1   8:113  0 1014M  0 part
`-sdh9   8:121  0    8M  0 part
sdi      8:128  0    1G  0 disk
|-sdi1   8:129  0 1014M  0 part
`-sdi9   8:137  0    8M  0 part
```
Команда `zpool status` показывает информацию о каждом диске, состоянии сканирования и об ошибках чтения, записи и совпадения хэш-сумм. Команда `zpool list` показывает информацию о размере пула, количеству занятого и свободного места, дедупликации и т.д.
Смотрим информацию о пулах:
```
[root@server vagrant]# zpool list
NAME    SIZE  ALLOC   FREE  CKPOINT  EXPANDSZ   FRAG    CAP  DEDUP    HEALTH  ALTROOT
otus1   960M   100K   960M        -         -     0%     0%  1.00x    ONLINE  -
otus2   960M   104K   960M        -         -     0%     0%  1.00x    ONLINE  -
otus3   960M   105K   960M        -         -     0%     0%  1.00x    ONLINE  -
otus4   960M   105K   960M        -         -     0%     0%  1.00x    ONLINE  -

[root@server vagrant]# zpool status
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

[root@server vagrant]# df -h
Filesystem      Size  Used Avail Use% Mounted on
devtmpfs        388M     0  388M   0% /dev
tmpfs           405M     0  405M   0% /dev/shm
tmpfs           405M  5.6M  399M   2% /run
tmpfs           405M     0  405M   0% /sys/fs/cgroup
/dev/sda2        62G  1.7G   61G   3% /
vagrant         466G  417G   50G  90% /vagrant
tmpfs            81M     0   81M   0% /run/user/1000
otus1           832M  128K  832M   1% /otus1
otus2           832M  128K  832M   1% /otus2
otus3           832M  128K  832M   1% /otus3
otus4           832M  128K  832M   1% /otus4
```
### Добавление сжатия на пулы
Добавим разные алгоритмы сжатия в каждую файловую систему:
```
[root@server vagrant]# zfs set compression=lzjb otus1
[root@server vagrant]# zfs set compression=lz4 otus2
[root@server vagrant]# zfs set compression=gzip-9 otus3
[root@server vagrant]# zfs set compression=zle otus4
[root@server vagrant]# zfs get all | grep compression
otus1  compression           lzjb                   local
otus2  compression           lz4                    local
otus3  compression           gzip-9                 local
otus4  compression           zle                    local
```
**Сжатие файлов будет работать только с файлами, которые были добавлены после включение настройки сжатия**

### Сравнение алгоритмов сжатия
Скачаем один и тот же файл в разные томаты
```
[root@server vagrant]# for i in {1..4}; do wget -P /otus$i https://gutenberg.org/cache/epub/2600/pg2600.converter.log; done
```

<details><summary>log</summary>

```
--2022-07-27 08:05:40--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 40841120 (39M) [text/plain]
Saving to: '/otus1/pg2600.converter.log'

pg2600.converter.log                     100%[===============================================================================>]  38.95M  5.19MB/s    in 17s

2022-07-27 08:05:58 (2.29 MB/s) - '/otus1/pg2600.converter.log' saved [40841120/40841120]

--2022-07-27 08:05:58--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 40841120 (39M) [text/plain]
Saving to: '/otus2/pg2600.converter.log'

pg2600.converter.log                     100%[===============================================================================>]  38.95M  5.35MB/s    in 11s

2022-07-27 08:06:10 (3.44 MB/s) - '/otus2/pg2600.converter.log' saved [40841120/40841120]

--2022-07-27 08:06:10--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 40841120 (39M) [text/plain]
Saving to: '/otus3/pg2600.converter.log'

pg2600.converter.log                     100%[===============================================================================>]  38.95M  3.53MB/s    in 12s

2022-07-27 08:06:23 (3.26 MB/s) - '/otus3/pg2600.converter.log' saved [40841120/40841120]

--2022-07-27 08:06:23--  https://gutenberg.org/cache/epub/2600/pg2600.converter.log
Resolving gutenberg.org (gutenberg.org)... 152.19.134.47
Connecting to gutenberg.org (gutenberg.org)|152.19.134.47|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 40841120 (39M) [text/plain]
Saving to: '/otus4/pg2600.converter.log'

pg2600.converter.log                     100%[===============================================================================>]  38.95M  4.93MB/s    in 12s

2022-07-27 08:06:36 (3.34 MB/s) - '/otus4/pg2600.converter.log' saved [40841120/40841120]
```
</details>

```
[root@server vagrant]# ls -l /otus*
/otus1:
total 22025
-rw-r--r--. 1 root root 40841120 Jul  2 08:39 pg2600.converter.log

/otus2:
total 17975
-rw-r--r--. 1 root root 40841120 Jul  2 08:39 pg2600.converter.log

/otus3:
total 10950
-rw-r--r--. 1 root root 40841120 Jul  2 08:39 pg2600.converter.log

/otus4:
total 39912
-rw-r--r--. 1 root root 40841120 Jul  2 08:39 pg2600.converter.log
```


Уже на этом этапе видно, что самый оптимальный метод сжатия у нас используется в пуле otus3.
Проверим, сколько места занимает один и тот же файл в разных пулах и
проверим степень сжатия файлов:
```
[root@server vagrant]# zfs list
NAME    USED  AVAIL     REFER  MOUNTPOINT
otus1  21.7M   810M     21.5M  /otus1
otus2  17.7M   814M     17.6M  /otus2
otus3  10.8M   821M     10.7M  /otus3
otus4  39.1M   793M     39.0M  /otus4

[root@server vagrant]# zfs get all | grep compressratio | grep -v ref
otus1  compressratio         1.81x                  -
otus2  compressratio         2.22x                  -
otus3  compressratio         3.64x                  -
otus4  compressratio         1.00x                  -
```
**Таким образом, у нас получается, что алгоритм gzip-9 самый эффективный по сжатию.**

## Определение настроек пула
Скачаем архив в домашний каталог:
```
[root@server vagrant]# wget -O archive.tar.gz --no-check-certificate https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg&export=download
[1] 7568
[root@server vagrant]#
Redirecting output to 'wget-log'.

[1]+  Done                    wget -O archive.tar.gz --no-check-certificate https://drive.google.com/u/0/uc?id=1KRBNW33QWqbvbVHa3hLJivOAt60yukkg
```
Разархивируем его:
```
[root@server vagrant]# tar -xzvf archive.tar.gz
zpoolexport/
zpoolexport/filea
zpoolexport/fileb
```
Проверим, возможно ли импортировать данный каталог в пул:
```
[root@server vagrant]# zpool import -d zpoolexport/
   pool: otus
     id: 6554193320433390805
  state: ONLINE
status: Some supported features are not enabled on the pool.
 action: The pool can be imported using its name or numeric identifier, though
        some features will not be available without an explicit 'zpool upgrade'.
 config:

        otus                                 ONLINE
          mirror-0                           ONLINE
            /home/vagrant/zpoolexport/filea  ONLINE
            /home/vagrant/zpoolexport/fileb  ONLINE
```
Сделаем импорт данного пула к нам в ОС:
```
[root@server vagrant]# zpool import -d zpoolexport/ otus
[root@server vagrant]# zpool status otus
  pool: otus
 state: ONLINE
status: Some supported features are not enabled on the pool. The pool can
        still be used, but some features are unavailable.
action: Enable all features using 'zpool upgrade'. Once this is done,
        the pool may no longer be accessible by software that does not support
        the features. See zpool-features(5) for details.
config:

        NAME                                 STATE     READ WRITE CKSUM
        otus                                 ONLINE       0     0     0
          mirror-0                           ONLINE       0     0     0
            /home/vagrant/zpoolexport/filea  ONLINE       0     0     0
            /home/vagrant/zpoolexport/fileb  ONLINE       0     0     0
errors: No known data errors
```
Запрос сразу всех параметров пула:
```
[root@server vagrant]# zpool get all otus
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
otus  load_guid                      9065799967302232891            -
otus  autotrim                       off                            default
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
```
Запрос сразу всех параметром файловой системы:
```
[root@server vagrant]# zfs get all otus
NAME  PROPERTY              VALUE                  SOURCE
otus  type                  filesystem             -
otus  creation              Fri May 15  4:00 2020  -
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
otus  relatime              off                    default
otus  redundant_metadata    all                    default
otus  overlay               on                     default
otus  encryption            off                    default
otus  keylocation           none                   default
otus  keyformat             none                   default
otus  pbkdf2iters           0                      default
otus  special_small_blocks  0                      default
```
Размер:
```
[root@server vagrant]# zfs get available otus
NAME  PROPERTY   VALUE  SOURCE
otus  available  350M   -
```
Тип:
```
[root@server vagrant]# zfs get readonly otus
NAME  PROPERTY  VALUE   SOURCE
otus  readonly  off     default
```
Значение recordsize:
```
[root@server vagrant]# zfs get recordsize otus
NAME  PROPERTY    VALUE    SOURCE
otus  recordsize  128K     local
```
Тип сжатия (или параметр отключения):
```
[root@server vagrant]# zfs get compression otus
NAME  PROPERTY     VALUE           SOURCE
otus  compression  zle             local
```
Тип контрольной суммы:
```
[root@server vagrant]# zfs get checksum otus
NAME  PROPERTY  VALUE      SOURCE
otus  checksum  sha256     local
```

## Работа со снапшотом, поиск сообщения от преподавателя
Скачаем файл, указанный в задании:
```
[root@server vagrant]# wget -O otus_task2.file --no-check-certificate "https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download"
--2022-07-27 20:03:05--  https://drive.google.com/u/0/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
Resolving drive.google.com (drive.google.com)... 142.251.1.194
Connecting to drive.google.com (drive.google.com)|142.251.1.194|:443... connected.
HTTP request sent, awaiting response... 302 Found
Location: https://drive.google.com/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download [following]
--2022-07-27 20:03:06--  https://drive.google.com/uc?id=1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG&export=download
Reusing existing connection to drive.google.com:443.
HTTP request sent, awaiting response... 303 See Other
Location: https://doc-00-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/50s8k7jgv39lbkj433iet87f5ukcfe2v/1658952150000/16189157874053420687/*/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG?e=download&uuid=b9bd8216-8593-4dc7-8025-42d26082f413 [following]
Warning: wildcards not supported in HTTP.
--2022-07-27 20:03:10--  https://doc-00-bo-docs.googleusercontent.com/docs/securesc/ha0ro937gcuc7l7deffksulhg5h7mbp1/50s8k7jgv39lbkj433iet87f5ukcfe2v/1658952150000/16189157874053420687/*/1gH8gCL9y7Nd5Ti3IRmplZPF1XjzxeRAG?e=download&uuid=b9bd8216-8593-4dc7-8025-42d26082f413
Resolving doc-00-bo-docs.googleusercontent.com (doc-00-bo-docs.googleusercontent.com)... 173.194.73.132
Connecting to doc-00-bo-docs.googleusercontent.com (doc-00-bo-docs.googleusercontent.com)|173.194.73.132|:443... connected.
HTTP request sent, awaiting response... 200 OK
Length: 5432736 (5.2M) [application/octet-stream]
Saving to: 'otus_task2.file'

otus_task2.file                          100%[===============================================================================>]   5.18M  9.69MB/s    in 0.5s

2022-07-27 20:03:12 (9.69 MB/s) - 'otus_task2.file' saved [5432736/5432736]
```
Восстановим файловую систему из снапшота:
```
[root@server vagrant]# zfs receive otus/test@today < otus_task2.file
```
Далее, ищем в каталоге `/otus/test` файл с именем “secret_message”:
```
[root@server vagrant]# find /otus/test -name "secret_message"
/otus/test/task1/file_mess/secret_message
```
Смотрим содержимое найденного файла:
```
[root@server vagrant]# cat /otus/test/task1/file_mess/secret_message
https://github.com/sindresorhus/awesome
```
https://github.com/sindresorhus/awesome
