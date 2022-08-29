# Bash скрипты
- [Bash скрипты](#bash-скрипты)
  - [Домашнее задание](#домашнее-задание)
    - [Скрипт](#скрипт)
      - [Usage](#usage)
      - [Основные функции](#основные-функции)
        - [top_n](#top_n)
        - [http_only](#http_only)
        - [send_email](#send_email)
      - [Подсчет в файле](#подсчет-в-файле)
        - [Обрабатываемое время](#обрабатываемое-время)
        - [ТОП IP адресов](#топ-ip-адресов)
        - [ТОП запрошенных URI](#топ-запрошенных-uri)
        - [ТОП запрошенных кодов возврата](#топ-запрошенных-кодов-возврата)
        - [Логи со статусом 4хх\5хх](#логи-со-статусом-4хх5хх)
    - [Результат](#результат)
## Домашнее задание
Необходимо распарсить файл [access.log](files/access.log)

Написать скрипт для CRON, который раз в час будет формировать письмо и отправлять на заданную почту.

Необходимая информация в письме:

- Список IP адресов (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
- Список запрашиваемых URL (с наибольшим кол-вом запросов) с указанием кол-ва запросов c момента последнего запуска скрипта;
- Ошибки веб-сервера/приложения c момента последнего запуска;
- Список всех кодов HTTP ответа с указанием их кол-ва с момента последнего запуска скрипта.
- Скрипт должен предотвращать одновременный запуск нескольких копий, до его завершения.
- В письме должен быть прописан обрабатываемый временной диапазон.

### Скрипт
[nginx-parser.sh](files/ngix-parser.sh)
#### Usage
```
Usage: nginx-parser.sh options
        -r|--recipient <destination email> - email address to send statistics to. Default: 'root'
        -l|--logfile <path/to/access.log> - path to nginx access.log to analyse. Default: './access.log'
        -L|--lockfile <path/to/lockfile.lock> - path to lockfile. Default: '/tmp/script.lock'
        -S|--state-dir <path/to/state/directory> - path to directory to save state. Default: './nginx_log_analyzer'
        -T|--top <num> - report top <num> results. Default: 10
        -h|--help - Print this help and exit
```
#### Основные функции
##### top_n
Считает, сортирует и выводит top полей входной строки (передаваемой в функцию)
```
top_n() {
  awk '{ print $1; }' | sort -n | uniq -c | sort -rn | head -n $TOP
}
```
##### http_only
Фильтрует только HTTP сообщения в логе:
```
http_only() {
  grep --color=never -P ' HTTP/[\d\.]+"'
}
```
##### send_email
```
# Send statistics to email
send_email() {
  cat $1 | wc -l
  cat $1 > ./result.txt
  cat $1 | mailx -v -s 'access.log stats' $RECIPIENT
}
```

#### Подсчет в файле
##### Обрабатываемое время
```
FROM_DT=$(sed -n "$(($FROM_LINE + 1)),$(($FROM_LINE + 1))p" $LOGFILE | cut -d"[" -f2 | cut -d"]" -f1)
TO_DT=$(sed -n "$(($TO_LINE)),$(($TO_LINE))p" $LOGFILE | cut -d"[" -f2 | cut -d"]" -f1)
```
##### ТОП IP адресов
ТОП IP адресов (1я позиция в строке лога)
```
echo "Top $TOP IPs"
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | awk '{ print $1; }' | top_n
```
##### ТОП запрошенных URI
```
echo "Top $TOP requested URIs"
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | http_only | awk '{ print $7; }' | top_n
```
##### ТОП запрошенных кодов возврата
```

echo "Return codes count"
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | http_only | awk '{ print $9; }' | sort -n | uniq -c | sort -rn
```

##### Логи со статусом 4хх\5хх
регулярное выражение на статус код (начинается с 4 или 5) и 2 числа 0-9
```
printf "Errors (4xx and 5xx):\n\n"
sed -n "$(($FROM_LINE + 1)),$(($TO_LINE))p" $LOGFILE | http_only | awk '$9 ~ /[45][0-9]{2}/ { print $0; }'
```

### Результат
```
Period from 14/Aug/2019:04:38:35 +0300 to 15/Aug/2019:00:25:46 +0300
--------
Top 10 IPs
     45 93.158.167.130
     39 109.236.252.130
     37 212.57.117.19
     33 188.43.241.106
     31 87.250.233.68
     24 62.75.198.172
     22 148.251.223.21
     20 185.6.8.9
     17 217.118.66.161
     16 95.165.18.146
--------
Top 10 requested URIs
    156 /
    120 /wp-login.php
     57 /xmlrpc.php
     26 /robots.txt
     12 /favicon.ico
      9 /wp-includes/js/wp-embed.min.js?ver=5.0.4
      7 /wp-admin/admin-post.php?page=301bulkoptions
      7 /1
      6 /wp-content/uploads/2016/10/robo5.jpg
      6 /wp-content/uploads/2016/10/robo4.jpg
--------
Return codes count
    497 200
     95 301
     51 404
      7 400
      3 500
      2 499
      1 405
      1 403
      1 304
--------
Errors (4xx and 5xx):

93.158.167.130 - - [14/Aug/2019:05:02:20 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:05:04:20 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
107.179.102.58 - - [14/Aug/2019:05:22:10 +0300] "GET /wp-content/plugins/uploadify/readme.txt HTTP/1.1" 404 200 "http://dbadmins.ru/wp-content/plugins/uploadify/readme.txt" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-"
193.106.30.99 - - [14/Aug/2019:06:02:50 +0300] "GET /wp-includes/ID3/comay.php HTTP/1.1" 500 595 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.103 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-"
87.250.244.2 - - [14/Aug/2019:06:07:07 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
77.247.110.165 - - [14/Aug/2019:06:13:53 +0300] "HEAD /robots.txt HTTP/1.0" 404 0 "-" "-"rt=0.018 uct="-" uht="-" urt="-"
87.250.233.76 - - [14/Aug/2019:06:45:20 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
71.6.199.23 - - [14/Aug/2019:07:07:19 +0300] "GET /robots.txt HTTP/1.1" 404 3652 "-" "-"rt=0.000 uct="-" uht="-" urt="-"
71.6.199.23 - - [14/Aug/2019:07:07:20 +0300] "GET /sitemap.xml HTTP/1.1" 404 3652 "-" "-"rt=0.000 uct="-" uht="-" urt="-"
71.6.199.23 - - [14/Aug/2019:07:07:20 +0300] "GET /.well-known/security.txt HTTP/1.1" 404 3652 "-" "-"rt=0.000 uct="-" uht="-" urt="-"
71.6.199.23 - - [14/Aug/2019:07:07:21 +0300] "GET /favicon.ico HTTP/1.1" 404 3652 "-" "python-requests/2.19.1"rt=0.000 uct="-" uht="-" urt="-"
141.8.141.136 - - [14/Aug/2019:07:09:43 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:08:10:56 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:08:21:48 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
62.75.198.172 - - [14/Aug/2019:08:23:40 +0300] "POST /wp-cron.php?doing_wp_cron=1565760219.4257180690765380859375 HTTP/1.1" 499 0 "https://dbadmins.ru/wp-cron.php?doing_wp_cron=1565760219.4257180690765380859375" "WordPress/5.0.4; https://dbadmins.ru"rt=1.001 uct="-" uht="-" urt="-"
78.39.67.210 - - [14/Aug/2019:08:23:41 +0300] "GET /admin/config.php HTTP/1.1" 404 29500 "-" "curl/7.15.5 (x86_64-redhat-linux-gnu) libcurl/7.15.5 OpenSSL/0.9.8b zlib/1.2.3 libidn/0.6.5"rt=0.480 uct="0.000" uht="0.192" urt="0.243"
176.9.56.104 - - [14/Aug/2019:08:30:17 +0300] "GET /1 HTTP/1.1" 404 29513 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.233 uct="0.000" uht="0.182" urt="0.233"
87.250.233.75 - - [14/Aug/2019:09:21:46 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
162.243.13.195 - - [14/Aug/2019:09:31:47 +0300] "POST /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 400 11 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.241 uct="0.000" uht="0.241" urt="0.241"
162.243.13.195 - - [14/Aug/2019:09:31:48 +0300] "GET /1 HTTP/1.1" 404 29500 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.308 uct="0.000" uht="0.187" urt="0.237"
162.243.13.195 - - [14/Aug/2019:09:31:50 +0300] "GET /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 400 11 "http://dbadmins.ru/wp-admin/admin-ajax.php?page=301bulkoptions" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.237 uct="0.000" uht="0.237" urt="0.237"
162.243.13.195 - - [14/Aug/2019:09:31:52 +0300] "GET /1 HTTP/1.1" 404 29500 "http://dbadmins.ru/1" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.303 uct="0.000" uht="0.180" urt="0.230"
217.118.66.161 - - [14/Aug/2019:10:21:00 +0300] "GET /wp-content/themes/llorix-one-lite/fonts/fontawesome-webfont.eot? HTTP/1.1" 403 46 "https://dbadmins.ru/2016/10/26/%D0%B8%D0%B7%D0%BC%D0%B5%D0%BD%D0%B5%D0%BD%D0%B8%D0%B5-%D1%81%D0%B5%D1%82%D0%B5%D0%B2%D1%8B%D1%85-%D0%BD%D0%B0%D1%81%D1%82%D1%80%D0%BE%D0%B5%D0%BA-%D0%B4%D0%BB%D1%8F-oracle-rac/" "Mozilla/5.0 (Windows NT 6.3; WOW64; Trident/7.0; Touch; rv:11.0) like Gecko"rt=0.000 uct="0.000" uht="0.000" urt="0.000"
93.158.167.130 - - [14/Aug/2019:10:27:26 +0300] "GET /robots.txt HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:10:27:30 +0300] "GET /sitemap.xml HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexBot/3.0; +http://yandex.com/bots)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:10:27:34 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:11:32:44 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
141.8.141.136 - - [14/Aug/2019:11:33:32 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
77.247.110.201 - - [14/Aug/2019:11:56:29 +0300] "GET /admin/config.php HTTP/1.1" 404 3652 "-" "curl/7.19.7 (x86_64-redhat-linux-gnu) libcurl/7.19.7 NSS/3.27.1 zlib/1.2.3 libidn/1.18 libssh2/1.4.2"rt=0.000 uct="-" uht="-" urt="-"
62.210.252.196 - - [14/Aug/2019:11:57:31 +0300] "POST /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 400 11 "-" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.236 uct="0.000" uht="0.236" urt="0.236"
62.210.252.196 - - [14/Aug/2019:11:57:32 +0300] "GET /1 HTTP/1.1" 404 29500 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.540 uct="0.000" uht="0.183" urt="0.540"
62.210.252.196 - - [14/Aug/2019:11:57:34 +0300] "GET /wp-admin/admin-ajax.php?page=301bulkoptions HTTP/1.1" 400 11 "http://dbadmins.ru/wp-admin/admin-ajax.php?page=301bulkoptions" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/36.0.1985.143 Safari/537.36"rt=0.232 uct="0.000" uht="0.232" urt="0.232"
62.210.252.196 - - [14/Aug/2019:11:57:35 +0300] "GET /1 HTTP/1.1" 404 29500 "http://dbadmins.ru/1" "Mozilla/5.0 (Windows NT 6.1; Win64; x64; rv:64.0) Gecko/20100101 Firefox/64.0"rt=0.262 uct="0.000" uht="0.212" urt="0.262"
60.208.103.154 - - [14/Aug/2019:11:59:33 +0300] "GET /manager/html HTTP/1.1" 404 3652 "-" "User-Agent:Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.2; .NET CLR 1.0.3705"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:12:35:00 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
118.139.177.119 - - [14/Aug/2019:12:58:37 +0300] "GET /w00tw00t.at.ISC.SANS.DFind:) HTTP/1.1" 400 173 "-" "-"rt=0.241 uct="-" uht="-" urt="-"
110.249.212.46 - - [14/Aug/2019:13:17:41 +0300] "GET http://110.249.212.46/testget?q=23333&port=80 HTTP/1.1" 400 173 "-" "-"rt=2.710 uct="-" uht="-" urt="-"
110.249.212.46 - - [14/Aug/2019:13:17:41 +0300] "GET http://110.249.212.46/testget?q=23333&port=443 HTTP/1.1" 400 173 "-" "-"rt=2.716 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:13:36:55 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
5.45.203.12 - - [14/Aug/2019:13:41:42 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:14:50:19 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:14:52:27 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
141.8.141.136 - - [14/Aug/2019:15:52:52 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:16:18:16 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
5.45.203.12 - - [14/Aug/2019:16:53:55 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
77.247.110.69 - - [14/Aug/2019:17:19:49 +0300] "HEAD /robots.txt HTTP/1.0" 404 0 "-" "-"rt=0.019 uct="-" uht="-" urt="-"
87.250.233.76 - - [14/Aug/2019:17:52:20 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:17:55:02 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:19:02:51 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:19:16:50 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
185.142.236.35 - - [14/Aug/2019:19:23:18 +0300] "GET /.well-known/security.txt HTTP/1.1" 404 169 "-" "-"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:20:03:43 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
62.75.198.172 - - [14/Aug/2019:20:25:44 +0300] "POST /wp-cron.php?doing_wp_cron=1565803543.6812090873718261718750 HTTP/1.1" 499 0 "https://dbadmins.ru/wp-cron.php?doing_wp_cron=1565803543.6812090873718261718750" "WordPress/5.0.4; https://dbadmins.ru"rt=1.002 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:20:40:19 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:20:42:50 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
107.179.102.58 - - [14/Aug/2019:20:46:45 +0300] "GET /wp-content/plugins/uploadify/includes/check.php HTTP/1.1" 500 595 "http://dbadmins.ru/wp-content/plugins/uploadify/includes/check.php" "Mozilla/5.0 (Windows NT 6.1; WOW64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/42.0.2311.152 Safari/537.36"rt=0.000 uct="-" uht="-" urt="-"
5.45.203.12 - - [14/Aug/2019:21:50:58 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
193.106.30.99 - - [14/Aug/2019:22:04:04 +0300] "POST /wp-content/uploads/2018/08/seo_script.php HTTP/1.1" 500 595 "-" "Mozilla/5.0 (Windows NT 6.1; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/73.0.3683.103 Safari/537.36"rt=0.062 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:22:05:00 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
87.250.233.68 - - [14/Aug/2019:22:56:43 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
93.158.167.130 - - [14/Aug/2019:23:31:56 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
77.247.110.165 - - [14/Aug/2019:23:44:18 +0300] "HEAD /robots.txt HTTP/1.0" 404 0 "-" "-"rt=0.017 uct="-" uht="-" urt="-"
87.250.233.68 - - [15/Aug/2019:00:00:37 +0300] "GET / HTTP/1.1" 404 169 "-" "Mozilla/5.0 (compatible; YandexMetrika/2.0; +http://yandex.com/bots yabs01)"rt=0.000 uct="-" uht="-" urt="-"
182.254.243.249 - - [15/Aug/2019:00:24:38 +0300] "PROPFIND / HTTP/1.1" 405 173 "-" "-"rt=0.214 uct="-" uht="-" urt="-"
182.254.243.249 - - [15/Aug/2019:00:24:38 +0300] "GET /webdav/ HTTP/1.1" 404 3652 "-" "Mozilla/5.0"rt=0.222 uct="-" uht="-" urt="-"
```
