#!/bin/bash

set -eux
echo "install nfs-utils"
sudo yum install -y nfs-utils

echo "enable firewall"
systemctl enable firewalld --now


echo "Mount NFSv3 UDP"
sudo echo "192.168.56.10:/srv/share/ /mnt nfs vers=3,proto=udp,noauto,x-systemd.automount 0 0" >> /etc/fstab
sudo systemctl daemon-reload
sudo systemctl restart remote-fs.target
cd /mnt/
mount | grep mnt

echo "Check test file"
ls -la /mnt/upload
