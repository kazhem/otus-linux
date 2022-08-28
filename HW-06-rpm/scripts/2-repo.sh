
#!/usr/bin/env bash

set -eux

echo Create repo directory
mkdir -p /usr/share/nginx/html/repo

echo Copy nginx rpm to repo directory
cp /home/vagrant/rpmbuild/RPMS/x86_64/nginx-1.22.0-1.el7.ngx.x86_64.rpm /usr/share/nginx/html/repo/

echo Also fetch percona server
wget -q http://www.percona.com/downloads/percona-release/redhat/0.1-6/percona-release-0.1-6.noarch.rpm -O /usr/share/nginx/html/repo/percona-release-0.1-6.noarch.rpm

echo Create repository structure
createrepo /usr/share/nginx/html/repo/

echo Configure nginx
sed -i '/index  index.html index.htm;/ a autoindex on;' /etc/nginx/conf.d/default.conf
sudo nginx -t && sudo nginx -s reload

echo Check repo available
curl -a http://localhost/repo/

echo Add repo to YUP repo list
cat <<EOF | tee /etc/yum.repos.d/otus.repo
[otus]
name=otus-linux
baseurl=http://localhost/repo
gpgcheck=0
enabled=1
EOF

echo Ensure repo is enabled
yum repolist enabled | grep otus

echo Reinstall nginx from addred repo
yum reinstall -y nginx --disablerepo="*" --enablerepo=otus

echo List packages in custom repo
yum repo-pkgs otus list all
