#!/bin/bash
#
# setup script for cockroach cluster
# https://www.cockroachlabs.com/docs/stable/install-cockroachdb.html

# -- configurations
version="2.0.5"
os="linux"
arch="amd64"

arch_name="cockroach-v$version.$os-$arch"
archive="https://binaries.cockroachdb.com/$arch_name.tgz"

root="/opt/cockroach"
bin="$root/cockroach"



# -- get node list from /etc/hosts
nodes=`grep store- /etc/hosts`

# -- get cockroach package and install locally
wget -q -O - "$archive" | sudo tar -C /opt -zxv

[ -d "$root" ] && sudo mv $root $root.`date +%Y%m%d_%H%M%S`
sudo mkdir -p $root/certs
sudo mkdir -p /var/lib/cockroach
sudo chown -R $USER $root
sudo chown -R $USER /var/lib/cockroach
chmod -R 750 $root
chmod -R 750 /var/lib/cockroach

ln -s /var/lib/cockroach $root/data
ln -s /opt/cockroach-v$version.$os-$arch/cockroach $root/cockroach

# -- create certifications
mkdir -p keys
chmod 700 keys

$bin cert create-ca --certs-dir=$root/certs --ca-key=keys/ca.key
$bin cert create-client root --certs-dir=$root/certs --ca-key=keys/ca.key

#openssl genrsa -out keys/ca.key 2048
#openssl req -new -key keys/ca.key -out keys/ca.csr \
#	-subj "/C=KO/ST=SEOUL/O=Company/OU=Team/CN=www.example.com"
#openssl x509 -req -in keys/ca.csr -signkey keys/ca.key -out certs/ca.crt



# -- preparing files
mkdir -p certs
cp -a $root/certs/ca.crt certs

cat > cockroach.ufw <<EOF
[CockroachDB]
title=CockroachDB
description=CockroachDB communication and administration
ports=26257,8080/tcp
EOF



# -- generate join list
clist=""

OIFS=$IFS
IFS=$'\n'
for node in $nodes; do
	addr=`echo $node |sed 's/\s/ /g' |cut -d' ' -f1`
	if [ "$clist" = "" ]; then
		clist="$addr:26257"
	else
		clist="$clist,$addr:26257"
	fi
done

# -- install cockroach to nodes...
for node in $nodes; do
	addr=`echo $node |sed 's/\s/ /g' |cut -d' ' -f1`
	hostname=`echo $node |sed 's/\s/ /g' |cut -d' ' -f2`
	alias=`echo $node |sed 's/\s/ /g' |cut -d' ' -f3`
	echo
	echo "install cockroach on $alias ($hostname, $addr)"

	$bin cert create-node \
		localhost $hostname $alias $addr $LB_NAME $LB_ADDR \
		--certs-dir=certs --ca-key=keys/ca.key \
		--overwrite
	cat > cockroach.service <<EOF
[Unit]
Description=cockroach database server
After=network.target
ConditionPathExists=!/var/tmp/cockroach_not_to_be_run

[Service]
WorkingDirectory=$root
ExecStart=$root/cockroach start --certs-dir=certs --store=path=data --host=$addr --join=$clist
ExecReload=/bin/kill -INT $MAINPID
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
	# -- install...
	scp -P 7422 -p -r \
		/opt/cockroach-v$version.$os-$arch/cockroach \
		cockroach.service \
		cockroach.ufw \
		certs \
		51.setup-cockroach-node.sh \
		$hostname:~/
	ssh -t -p 7422 $hostname "bash 51.setup-cockroach-node.sh"
done

# -- clean up
rm -rf certs cockroach.service cockroach.ufw
