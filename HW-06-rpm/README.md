# Управление пакетами
- [Управление пакетами](#управление-пакетами)
  - [Домашние задание](#домашние-задание)
    - [Создание своего RPM пакета](#создание-своего-rpm-пакета)
      - [Подготовка](#подготовка)
      - [Получение исходников NGINX и openssl](#получение-исходников-nginx-и-openssl)
      - [Установка зависимостей NGINX](#установка-зависимостей-nginx)
      - [Сборка RPM пакета](#сборка-rpm-пакета)
      - [Установка и запуск собранного пакета](#установка-и-запуск-собранного-пакета)
    - [Создание своего RPM репозитория](#создание-своего-rpm-репозитория)
      - [Подготовка](#подготовка-1)
      - [Создание репозитория](#создание-репозитория)
      - [Настройка NGINX для доступа к каталогу с пакетами](#настройка-nginx-для-доступа-к-каталогу-с-пакетами)
      - [Добавление нашего репозитория в систему](#добавление-нашего-репозитория-в-систему)

## Домашние задание

1. Создать свой RPM пакет (можно взять свое приложение, либо собрать, например, апач с определенными опциями)
1. Создать свой репозиторий и разместить там ранее собранный RPM
Реализовать это все либо в Vagrant, либо развернуть у себя через NGINX и дать ссылку на репозиторий.


### Создание своего RPM пакета
#### Подготовка
Необходимо установить следующие пакеты:
```
sudo yum install -y \
   redhat-lsb-core \
   wget \
   rpmdevtools \
   rpm-build \
   createrepo \
   yum-utils
```
Для примера возьмем пакет NGINX и соберем его с поддержкой openssl

#### Получение исходников NGINX и openssl
Загрузим SRPM пакет NGINX для дальнейшей работы над ним:
```
[vagrant@hw-06-rpm ~]$ wget https://nginx.org/packages/centos/7/SRPMS/nginx-1.22.0-1.el7.ngx.src.rpm
```
При установке такого пакета в домашней директории создается древо каталогов для сборки:
```
[vagrant@hw-06-rpm ~]$ rpm -i nginx-1.22.0-1.el7.ngx.src.rpm

[vagrant@hw-06-rpm ~]$ tree ./rpmbuild/
./rpmbuild/
|-- SOURCES
|   |-- logrotate
|   |-- nginx-1.22.0.tar.gz
|   |-- nginx-debug.service
|   |-- nginx.check-reload.sh
|   |-- nginx.conf
|   |-- nginx.copyright
|   |-- nginx.default.conf
|   |-- nginx.service
|   |-- nginx.suse.logrotate
|   `-- nginx.upgrade.sh
`-- SPECS
    `-- nginx.spec

2 directories, 11 files
```
Также нужно скачать и разархивировать последний исходники для openssl - он потребуется при сборке (c 3ей версии openssl сборка не прошла)
```
[vagrant@hw-06-rpm ~]$ wget --no-check-certificate  https://www.openssl.org/source/openssl-1.1.1q.tar.gz
[vagrant@hw-06-rpm ~]$ tar -xvf openssl-1.1.1q.tar.gz
```

#### Установка зависимостей NGINX
```
sudo yum-builddep --verbose --assumeyes rpmbuild/SPECS/nginx.spec
```
Добавим в `rpmbuild/SPECS/nginx.spec` `--with-openssl="/home/vagrant/openssl-3.0.5"`:
```
# [vagrant@hw-06-rpm ~]$ vi rpmbuild/SPECS/nginx.spec
...
%build
./configure %{BASE_CONFIGURE_ARGS} \
    --with-cc-opt="%{WITH_CC_OPT}" \
    --with-ld-opt="%{WITH_LD_OPT}" \
    --with-openssl="/home/vagrant/openssl-1.1.1q" \
    --with-debug
...
```
#### Сборка RPM пакета
```
[vagrant@hw-06-rpm ~]$ rpmbuild -bb rpmbuild/SPECS/nginx.spec
...
Выполняется(%clean): /bin/sh -e /var/tmp/rpm-tmp.uKGWWg
+ umask 022
+ cd /home/vagrant/rpmbuild/BUILD
+ cd nginx-1.22.0
+ /usr/bin/rm -rf /home/vagrant/rpmbuild/BUILDROOT/nginx-1.22.0-1.el7.ngx.x86_64
+ exit 0
```
Проверка:
```
[vagrant@hw-06-rpm ~]$ ls -l rpmbuild/RPMS/x86_64/
total 4124
-rw-rw-r--. 1 vagrant vagrant 2206868 авг 28 10:24 nginx-1.22.0-1.el7.ngx.x86_64.rpm
-rw-rw-r--. 1 vagrant vagrant 2011276 авг 28 10:24 nginx-debuginfo-1.22.0-1.el7.ngx.x86_64.rpm
```
#### Установка и запуск собранного пакета
```
[vagrant@hw-06-rpm ~]$ sudo yum localinstall -y rpmbuild/RPMS/x86_64/nginx-1.22.0-1.el7.ngx.x86_64.rpm
...
Installed:
  nginx.x86_64 1:1.22.0-1.el7.ngx

Complete!
[vagrant@hw-06-rpm ~]$ nginx -v
nginx version: nginx/1.22.0
```
```
[vagrant@hw-06-rpm ~]$ sudo systemctl start nginx
[vagrant@hw-06-rpm ~]$ systemctl status nginx
● nginx.service - nginx - high performance web server
   Loaded: loaded (/usr/lib/systemd/system/nginx.service; disabled; vendor preset: disabled)
   Active: active (running) since Вс 2022-08-28 10:30:14 UTC; 11s ago
     Docs: http://nginx.org/en/docs/
  Process: 16276 ExecStart=/usr/sbin/nginx -c /etc/nginx/nginx.conf (code=exited, status=0/SUCCESS)
 Main PID: 16277 (nginx)
   CGroup: /system.slice/nginx.service
           ├─16277 nginx: master process /usr/sbin/nginx -c /etc/nginx/nginx.conf
           ├─16278 nginx: worker process
           └─16279 nginx: worker process
[vagrant@hw-06-rpm ~]$
```
```
[vagrant@hw-06-rpm ~]$ curl -I localhost
HTTP/1.1 200 OK
Server: nginx/1.22.0
Date: Sun, 28 Aug 2022 10:31:05 GMT
Content-Type: text/html
Content-Length: 615
Last-Modified: Sun, 28 Aug 2022 10:24:37 GMT
Connection: keep-alive
ETag: "630b4265-267"
Accept-Ranges: bytes
```

### Создание своего RPM репозитория
#### Подготовка
Директория для статики у NGINX по умолчанию /usr/share/nginx/html. Создадим там каталог repo:
```
sudo mkdir -p /usr/share/nginx/html/repo
```
Копируем туда наш собранный RPM:
```
[vagrant@hw-06-rpm ~]$ sudo cp rpmbuild/RPMS/x86_64/nginx-1.22.0-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo
```
и RPM для установки репозитория Percona-Server
```
sudo wget -q http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm
```
```
[vagrant@hw-06-rpm ~]$ ls -la /usr/share/nginx/html/repo/
total 2220
drwxr-xr-x. 2 root root      87 авг 28 10:51 .
drwxr-xr-x. 3 root root      52 авг 28 10:48 ..
-rw-r--r--. 1 root root 2206868 авг 28 10:50 nginx-1.22.0-1.el7.ngx.x86_64.rpm
-rw-r--r--. 1 root root   64421 авг 28  2022 percona-release-0.1-6.noarch.rpm
```
#### Создание репозитория
Инициализируем репозиторий командой:
```
[vagrant@hw-06-rpm ~]$ sudo createrepo /usr/share/nginx/html/repo/
```
```
[vagrant@hw-06-rpm ~]$ tree /usr/share/nginx/html/repo/
/usr/share/nginx/html/repo/
├── nginx-1.22.0-1.el7.ngx.x86_64.rpm
├── percona-release-0.1-6.noarch.rpm
└── repodata
    ├── 03dd1066cfa24dd2da6bce21c3797bf056cf37c3ed037da8a235a8739e9d637b-other.xml.gz
    ├── 6784717d766d42bfb48cb2b26d5297af553441dd760a795404a0b9a45a070cd2-primary.xml.gz
    ├── aa3e28c5e8141fbed71c841ceb228b22659cd1fdf81de552e8947f8c10b53718-filelists.sqlite.bz2
    ├── cb46dd9a7241414b6f1ead57ae36f88863e1d3747594899e3861b4f0562cc498-other.sqlite.bz2
    ├── eb63cf7d9c8e68ea92db17ca609bc15837777a96e2fa1adca6f7f04b348cbd21-filelists.xml.gz
    ├── ee47aa48cca005486644aa204b69b5b78b29f01f12b187c1f5fb543ebad1804d-primary.sqlite.bz2
    └── repomd.xml

1 directory, 9 files
```
#### Настройка NGINX для доступа к каталогу с пакетами
В location / в файле `/etc/nginx/conf.d/default.conf` добавим директиву `autoindex on`. В результате location будет выглядеть так
```
 location / {
        root   /usr/share/nginx/html;
        index  index.html index.htm;
        autoindex on;
    }
```
Проверим синтаксис nginx и перезапустим
```
[vagrant@hw-06-rpm ~]$ sudo nginx -t
nginx: the configuration file /etc/nginx/nginx.conf syntax is ok
nginx: configuration file /etc/nginx/nginx.conf test is successful
```
```
[vagrant@hw-06-rpm ~]$ sudo nginx -s reload
[vagrant@hw-06-rpm ~]$ curl -a http://localhost/repo/
<html>
<head><title>Index of /repo/</title></head>
<body>
<h1>Index of /repo/</h1><hr><pre><a href="../">../</a>
<a href="repodata/">repodata/</a>                                          28-Aug-2022 11:25                   -
<a href="nginx-1.22.0-1.el7.ngx.x86_64.rpm">nginx-1.22.0-1.el7.ngx.x86_64.rpm</a>                  28-Aug-2022 10:50             2206868
<a href="percona-release-0.1-6.noarch.rpm">percona-release-0.1-6.noarch.rpm</a>                   11-Nov-2020 21:48               14520
</pre><hr></body>
</html>
```
#### Добавление нашего репозитория в систему
Добавим репу в `/etc/yum.repos.d`:
```
[vagrant@hw-06-rpm ~]$ cat << EOF | sudo tee /etc/yum.repos.d/otus.repo
> [otus]
> name=otus-linux
> baseurl=http://localhost/repo
> gpgcheck=0
> enabled=1
> EOF
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
[vagrant@hw-06-rpm ~]$
```
Проверим, что репозиторий подключился и его содержимое:
```
[vagrant@hw-06-rpm ~]$ yum repolist enabled | grep otus
otus                                otus-linux                                 2
```
```
[vagrant@hw-06-rpm ~]$ sudo yum reinstall -y nginx --disablerepo="*" --enablerepo=otus
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
Resolving Dependencies
--> Running transaction check
---> Package nginx.x86_64 1:1.22.0-1.el7.ngx will be reinstalled
--> Finished Dependency Resolution

Dependencies Resolved

=========================================================================================================================================
 Package                      Arch                          Version                                    Repository                   Size
=========================================================================================================================================
Reinstalling:
 nginx                        x86_64                        1:1.22.0-1.el7.ngx                         otus                        2.1 M

Transaction Summary
=========================================================================================================================================
Reinstall  1 Package

Total download size: 2.1 M
Installed size: 6.1 M
Downloading packages:
nginx-1.22.0-1.el7.ngx.x86_64.rpm                                                                                 | 2.1 MB  00:00:00
Running transaction check
Running transaction test
Transaction test succeeded
Running transaction
  Installing : 1:nginx-1.22.0-1.el7.ngx.x86_64                                                                                       1/1
  Verifying  : 1:nginx-1.22.0-1.el7.ngx.x86_64                                                                                       1/1

Installed:
  nginx.x86_64 1:1.22.0-1.el7.ngx

Complete!
```
```
[vagrant@hw-06-rpm ~]$ sudo yum repo-pkgs otus list all
Loaded plugins: fastestmirror
Loading mirror speeds from cached hostfile
 * base: centos-mirror.rbc.ru
 * extras: centos-mirror.rbc.ru
 * updates: mirror.yandex.ru
Installed Packages
nginx.x86_64                                                        1:1.22.0-1.el7.ngx                                              @otus
Available Packages
percona-release.noarch                                              0.1-6                                                           otus
```

[Vagrantfile](./Vagrantfile) с выполнением (через provisioning) добавлен
c
