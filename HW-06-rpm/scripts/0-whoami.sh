#!/bin/sh

set -eux

echo "Print some info about a host"
whoami
uname -a
hostname -f
ip addr show dev eth1
