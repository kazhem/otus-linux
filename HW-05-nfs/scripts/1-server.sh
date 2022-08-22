#!/bin/bash

set -eux

echo "Install packages for NFS server"
sudo yum install -y nfs-utils

echo "Enable services for NFS server"
sudo systemctl enable rpcbind
sudo systemctl enable nfs-server
sudo systemctl enable rpc-statd
sudo systemctl enable nfs-idmapd

echo "Start nfs services"
sudo systemctl start rpcbind
sudo systemctl start nfs-server
sudo systemctl start rpc-statd
sudo systemctl start nfs-idmapd

echo "Create directory"
sudo mkdir -p /srv/share/upload
chown -R nfsnobody:nfsnobody /srv/share
sudo chmod 0777 /srv/share/upload

echo "Provide config"
cat << EOF | sudo tee /etc/exports
/srv/share 192.168.56.0/24(rw,sync,root_squash)
EOF

echo "Apply config changes"
sudo exportfs -ra

echo "Create test file"
touch /srv/share/upload/test_file

echo "Enable firewall"
{
  sudo systemctl enable firewalld
  sudo systemctl start firewalld
  sudo firewall-cmd --permanent --add-service=nfs3
  sudo firewall-cmd --permanent --add-service=mountd
  sudo firewall-cmd --permanent --add-service=rpc-bind
  sudo firewall-cmd --reload
  sudo firewall-cmd --list-all
}
