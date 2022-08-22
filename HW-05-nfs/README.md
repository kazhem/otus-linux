# Стенд Vagrant с NFS
- [Стенд Vagrant с NFS](#стенд-vagrant-с-nfs)
  - [Домашние задание](#домашние-задание)
    - [Настройка сервера NFS](#настройка-сервера-nfs)
    - [Настройка клиента NFS](#настройка-клиента-nfs)
    - [Проверка работоспособности](#проверка-работоспособности)
      - [Предварительные проверки](#предварительные-проверки)
      - [Проверки сервера после рестарта](#проверки-сервера-после-рестарта)
      - [Проверки клиента после рестарта](#проверки-клиента-после-рестарта)
    - [Vagrant file с provisioning](#vagrant-file-с-provisioning)

## Домашние задание
NFS:

- vagrant up должен поднимать 2 виртуалки: сервер и клиент;
- на сервер должна быть расшарена директория;
- на клиента она должна автоматически монтироваться при старте (fstab или autofs);
- в шаре должна быть папка upload с правами на запись;
- требования для NFS: NFSv3 по UDP, включенный firewall.
- `*` Настроить аутентификацию через KERBEROS (NFSv4)
### Настройка сервера NFS
Установим nfs утилиты для отладки
```bash
yum install nfs-utils
```
Включим firewall
```
systemctl enable firewalld --now
systemctl status firewalld
```
```
[root@nfs-server vagrant]# systemctl enable firewalld --now
Created symlink from /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service to /usr/lib/systemd/system/firewalld.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/firewalld.service to /usr/lib/systemd/system/firewalld.service.

[root@nfs-server vagrant]# systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Thu 2022-07-28 21:45:21 UTC; 21s ago
     Docs: man:firewalld(1)
 Main PID: 3157 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─3157 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

Jul 28 21:45:21 nfs-server systemd[1]: Starting firewalld - dynamic firewall daemon...
Jul 28 21:45:21 nfs-server systemd[1]: Started firewalld - dynamic firewall daemon.
Jul 28 21:45:21 nfs-server firewalld[3157]: WARNING: AllowZoneDrifting is enabled. This is considered an insecure configuration option. It will be removed in a future release. Please consider disabling it now.


```
Разрешаем в firewall доступ к сервисам NFS
```bash
firewall-cmd --add-service="nfs3" \
    --add-service="rpc-bind" \
    --add-service="mountd" \
    --permanent
firewall-cmd --reload
```
```
[root@nfs-server vagrant]# firewall-cmd --add-service="nfs3" \
> --add-service="rpc-bind" \
> --add-service="mountd" \
> --permanent
success
[root@nfs-server vagrant]# firewall-cmd --reload
success
```
Включаем сервер NFS (для конфигурации NFSv3 over UDP он не требует дополнительной настройки, однако вы можете ознакомиться с умолчаниями в файле `/etc/nfs.conf`
```
systemctl enable nfs --now
```
```
[root@nfs-server vagrant]# systemctl enable nfs --now
Created symlink from /etc/systemd/system/multi-user.target.wants/nfs-server.service to /usr/lib/systemd/system/nfs-server.service.
```
Проверяем наличие слушаемых портов 2049/udp, 2049/tcp, 20048/udp, 20048/tcp, 111/udp, 111/tcp
```
[vagrant@nfs-server ~]$ ss -tnplu | grep -e "2049\|20048\|111"
udp    UNCONN     0      0         *:2049                  *:*
udp    UNCONN     0      0         *:111                   *:*
udp    UNCONN     0      0         *:20048                 *:*
udp    UNCONN     0      0      [::]:2049               [::]:*
udp    UNCONN     0      0      [::]:111                [::]:*
udp    UNCONN     0      0      [::]:20048              [::]:*
tcp    LISTEN     0      64        *:2049                  *:*
tcp    LISTEN     0      128       *:111                   *:*
tcp    LISTEN     0      128       *:20048                 *:*
tcp    LISTEN     0      64     [::]:2049               [::]:*
tcp    LISTEN     0      128    [::]:111                [::]:*
tcp    LISTEN     0      128    [::]:20048              [::]:*
```
Cоздаём и настраиваем директорию, которая будет экспортирована
в будущем
```
[root@nfs-server vagrant]# mkdir -p /srv/share/upload
[root@nfs-server vagrant]# chown -R nfsnobody:nfsnobody /srv/share
[root@nfs-server vagrant]# chmod 0777 /srv/share/upload
[root@nfs-server vagrant]# cat << EOF > /etc/exports
> /srv/share 192.168.56.0/24(rw,sync,root_squash)
> EOF
```

```
[root@nfs-server vagrant]# exportfs -r    <-- экспортируем ранее созданную директорию
[root@nfs-server vagrant]# exportfs -s    <-- проверяем экспортированную директорию
/srv/share  192.168.56.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)
```
### Настройка клиента NFS
```
vagrant ssh nfs-client
```

Доустановим вспомогательные утилиты
```
[root@nfs-client vagrant]# yum install nfs-utils
```
Включаем firewall и проверяем, что он работает
```
[root@nfs-client vagrant]# systemctl enable firewalld --now
Created symlink from /etc/systemd/system/dbus-org.fedoraproject.FirewallD1.service to /usr/lib/systemd/system/firewalld.service.
Created symlink from /etc/systemd/system/multi-user.target.wants/firewalld.service to /usr/lib/systemd/system/firewalld.service.

[root@nfs-client vagrant]# systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2022-08-22 07:06:09 UTC; 7s ago
     Docs: man:firewalld(1)
 Main PID: 1177 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─1177 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

Aug 22 07:06:09 nfs-client systemd[1]: Starting firewalld - dynamic firewall daemon...
Aug 22 07:06:09 nfs-client systemd[1]: Started firewalld - dynamic firewall daemon.
```
добавляем в `/etc/fstab` строку
```
[root@nfs-client vagrant]# echo "192.168.56.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab
[root@nfs-client vagrant]# systemctl daemon-reload
[root@nfs-client vagrant]# systemctl restart remote-fs.target
```
Проверяем:
```
[root@nfs-client vagrant]# cd /mnt/
[root@nfs-client mnt]# mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=47,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=19003)
192.168.56.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.56.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.56.10)
```
*Обратите внимание на `vers=3` и `proto=udp`, что соответствует NFSv3
over UDP, как того требует задание*

### Проверка работоспособности
#### Предварительные проверки
```
vagrant ssh nfs-server

[vagrant@nfs-server ~]$ cd /srv/share/upload/
[vagrant@nfs-server upload]$ touch check_file
```
```
vagrant ssh nfs-client
[vagrant@nfs-client upload]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 24 Aug 22 07:21 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Aug 22 06:47 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Aug 22 07:21 check_file
```
#### Проверки сервера после рестарта
Перезагружаем сервер
```
[root@nfs-server vagrant]# shutdown -r now
```
Проверяем статусы nfs сервисов и файлы на сервере
```
[root@nfs-server vagrant]# ls -la /srv/share/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 24 Aug 22 07:21 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Aug 22 06:47 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Aug 22 07:21 check_file

[root@nfs-server vagrant]# systemctl status nfs
● nfs-server.service - NFS server and services
   Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
  Drop-In: /run/systemd/generator/nfs-server.service.d
           └─order-with-mounts.conf
   Active: active (exited) since Mon 2022-08-22 07:25:25 UTC; 13min ago
  Process: 841 ExecStartPost=/bin/sh -c if systemctl -q is-active gssproxy; then systemctl reload gssproxy ; fi (code=exited, status=0/SUCCESS)
  Process: 821 ExecStart=/usr/sbin/rpc.nfsd $RPCNFSDARGS (code=exited, status=0/SUCCESS)
  Process: 816 ExecStartPre=/usr/sbin/exportfs -r (code=exited, status=0/SUCCESS)
 Main PID: 821 (code=exited, status=0/SUCCESS)
   CGroup: /system.slice/nfs-server.service

Aug 22 07:25:25 nfs-server systemd[1]: Starting NFS server and services...
Aug 22 07:25:25 nfs-server systemd[1]: Started NFS server and services.

[root@nfs-server vagrant]# systemctl status firewalld
● firewalld.service - firewalld - dynamic firewall daemon
   Loaded: loaded (/usr/lib/systemd/system/firewalld.service; enabled; vendor preset: enabled)
   Active: active (running) since Mon 2022-08-22 07:25:22 UTC; 14min ago
     Docs: man:firewalld(1)
 Main PID: 419 (firewalld)
   CGroup: /system.slice/firewalld.service
           └─419 /usr/bin/python2 -Es /usr/sbin/firewalld --nofork --nopid

Aug 22 07:25:21 nfs-server systemd[1]: Starting firewalld - dynamic firewall daemon...
Aug 22 07:25:22 nfs-server systemd[1]: Started firewalld - dynamic firewall daemon.
Aug 22 07:25:22 nfs-server firewalld[419]: WARNING: AllowZoneDrifting is enabled. This is considered an insecure configuratio...it now.
Hint: Some lines were ellipsized, use -l to show in full.

[root@nfs-server vagrant]# exportfs -s
/srv/share  192.168.56.0/24(sync,wdelay,hide,no_subtree_check,sec=sys,rw,secure,root_squash,no_all_squash)

[root@nfs-server vagrant]# showmount -a 192.168.56.10
All mount points on 192.168.56.10:
192.168.56.11:/srv/share
```

#### Проверки клиента после рестарта
Перезагружаем клиент
```
[root@nfs-client vagrant]# shutdown -r now
```
```
[vagrant@nfs-client ~]$ cd /mnt/
[vagrant@nfs-client mnt]$ showmount -a 192.168.56.10
All mount points on 192.168.56.10:
192.168.56.11:/srv/share

[vagrant@nfs-client mnt]$ mount | grep mnt
systemd-1 on /mnt type autofs (rw,relatime,fd=21,pgrp=1,timeout=0,minproto=5,maxproto=5,direct,pipe_ino=11487)
192.168.56.10:/srv/share/ on /mnt type nfs (rw,relatime,vers=3,rsize=32768,wsize=32768,namlen=255,hard,proto=udp,timeo=11,retrans=3,sec=sys,mountaddr=192.168.56.10,mountvers=3,mountport=20048,mountproto=udp,local_lock=none,addr=192.168.56.10)

[vagrant@nfs-client mnt]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 24 Aug 22 07:21 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Aug 22 06:47 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Aug 22 07:21 check_file

[vagrant@nfs-client upload]$ touch final_check
[vagrant@nfs-client upload]$ ls -la
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 43 Aug 22 07:46 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Aug 22 06:47 ..
-rw-rw-r--. 1 vagrant   vagrant    0 Aug 22 07:21 check_file
-rw-rw-r--. 1 vagrant   vagrant    0 Aug 22 07:46 final_check
```
### Vagrant file с provisioning
Удалим стенд
```
vagrant destroy
```

Добавим provisioning файлы для [клиента](scripts/1-client.sh) и [сервера](scripts/1-server.sh)

Запустим `vagrant up`

Зайдем на клиент:
```
vagrant ssh nfs-client
```

```
[vagrant@nfs-client ~]$ ls -la /mnt/upload/
total 0
drwxrwxrwx. 2 nfsnobody nfsnobody 23 Aug 22 08:03 .
drwxr-xr-x. 3 nfsnobody nfsnobody 20 Aug 22 08:03 ..
-rw-r--r--. 1 root      root       0 Aug 22 08:03 test_file
```
Все работает
