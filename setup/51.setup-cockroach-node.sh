#!/bin/bash
#
# sub script for cockroach node

set -e

# -- configuration for cockroach node
host=`hostname -f`
addr=`hostname -i`
arch_name=`ls -d cockroach-v*`

[ "$arch_name" = "" ] && {
	echo "arch_name detection failed!" >&2
	exit 1
}

# -- installation structure
data="/var/lib/cockroach"
root="/opt/cockroach"
bin="$root/cockroach"

date=`date +%Y%m%d_%H%M%S`


# -- install cockroach package and setup structure
echo "install $arch_name..."
sudo rm -rf /opt/$arch_name
sudo mv $arch_name /opt/
sudo chown -R root.root /opt/$arch_name

sudo mkdir -p $root/certs
sudo mkdir -p $data
sudo chown -R $USER $root
sudo chown -R $USER $data
chmod 750 $root
chmod 750 $root/certs
chmod 750 $data

[ -e "$root/data" ] || ln -s $data $root/data
[ -h "$root/cockroach" ] && rm -f $root/cockroach
[ -e "$root/cockroach" ] && mv -f $root/cockroach $root/cockroach.old
ln -s /opt/$arch_name/cockroach $root/cockroach

for f in certs/*; do
	if [ -e "$root/$f" ]; then
		echo "- file $root/$f already exists. skip." >&2
	else
		mv $f $root/certs/
	fi
done
chmod 600 $root/certs/*
rm -rf certs


echo "install system files..."
sudo mv -f cockroach.ufw /etc/ufw/applications.d/cockroach
sudo chown root.root /etc/ufw/applications.d/cockroach
sudo ufw allow from any to any app CockroachDB

sudo cp /etc/hosts /etc/hosts.$date
sudo sed -i '/for-cockroach-begin/,/for-cockroach-end/d' /etc/hosts
echo -e "# for-cockroach-begin" |sudo tee -a /etc/hosts
cat hosts.dist |sudo tee -a /etc/hosts
echo -e "# for-cockroach-end" |sudo tee -a /etc/hosts
rm hosts.dist

mv -f cockroach.service $root/
sudo systemctl enable $root/cockroach.service

rm $0
