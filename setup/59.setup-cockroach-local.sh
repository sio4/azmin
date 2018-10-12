#!/bin/bash
#
# setup script for cockroach cluster
# https://www.cockroachlabs.com/docs/stable/install-cockroachdb.html

set -ex

# -- configurations
version="2.0.6"
os="linux"
arch="amd64"

arch_name="cockroach-v$version.$os-$arch"
archive="https://binaries.cockroachdb.com/$arch_name.tgz"


# -- installation structure
data="/var/lib/cockroach"
root="/opt/cockroach"
bin="$root/cockroach"


# -- get cockroach package and install locally
sudo rm -rf /opt/$arch_name
wget -q -O - "$archive" | sudo tar -C /opt -zxv
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
[ -e "$root/cockroach" ] && mv $root/cockroach $root/cockroach.old
ln -s /opt/$arch_name/cockroach $root/cockroach


# -- create certifications
mkdir -p keys
chmod 700 keys

if [ ! -e "keys/ca.key" ]; then
	$bin cert create-ca \
		--certs-dir=$root/certs --ca-key=keys/ca.key
fi
if [ ! -e "$root/certs/client.root.crt" ]; then
	$bin cert create-client root \
		--certs-dir=$root/certs --ca-key=keys/ca.key
fi
if [ ! -e "$root/certs/node.crt" ]; then
	$bin cert create-node \
		localhost 127.0.0.1 `hostname -a` `hostname -f` `hostname -i` \
		--certs-dir=$root/certs --ca-key=keys/ca.key
fi


# -- setup systemd
cat > $root/cockroach.service <<EOF
[Unit]
Description=cockroach database server
After=network.target
ConditionPathExists=!$root/cockroach_not_to_be_run

[Service]
WorkingDirectory=$root
ExecStart=$root/cockroach start --certs-dir=certs --store=path=data
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=on-failure
RestartPreventExitStatus=255
Type=simple
User=azmin
Group=zees
SyslogFacility=local0

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl enable $root/cockroach.service

