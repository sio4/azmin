#!/bin/bash
#
# sub script for cockroach node

## configuration for cockroach version
host=`hostname -f`
addr=`hostname -i`

## installation environment
root=/opt/cockroach
bin=$root/cockroach

[ -d "$root" ] && sudo mv $root $root.`date +%Y%m%d_%H%M%S`

sudo mkdir -p $root/certs
sudo mkdir -p /var/lib/cockroach
sudo chown -R $USER $root
sudo chown -R $USER /var/lib/cockroach
chmod -R 750 $root
chmod -R 750 /var/lib/cockroach
ln -s /var/lib/cockroach $root/data
mv cockroach $root/cockroach
mv cockroach.service $root/
mv certs/* $root/certs/
rmdir certs
sudo mv cockroach.ufw /etc/ufw/applications.d/cockroach
sudo chown root.root /etc/ufw/applications.d/cockroach

sudo ufw allow from any to any app CockroachDB

sudo systemctl enable $root/cockroach.service
