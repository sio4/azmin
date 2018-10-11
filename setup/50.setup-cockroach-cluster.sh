#!/bin/bash
#
# setup script for cockroach cluster
# https://www.cockroachlabs.com/docs/stable/install-cockroachdb.html

set -e

# -- configurations
version="2.0.6"
os="linux"
arch="amd64"

arch_name="cockroach-v$version.$os-$arch"
archive="https://binaries.cockroachdb.com/$arch_name.tgz"


# -- get node list from /etc/hosts
nodes=`grep crdb- /etc/hosts`
echo "$nodes" > hosts.dist


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
	$bin cert create-ca --certs-dir=$root/certs --ca-key=keys/ca.key
fi
if [ ! -e "$root/certs/ca.crt" ]; then
	$bin cert create-client root --certs-dir=$root/certs --ca-key=keys/ca.key
fi


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
	alias=`echo $node |sed 's/\s/ /g' |cut -d' ' -f3`
	if [ "$clist" = "" ]; then
		clist="$alias:26257"
	else
		clist="$clist,$alias:26257"
	fi
done

# -- install cockroach to nodes...
for node in $nodes; do
	addr=`echo $node |sed 's/\s/ /g' |cut -d' ' -f1`
	hostname=`echo $node |sed 's/\s/ /g' |cut -d' ' -f2`
	alias=`echo $node |sed 's/\s/ /g' |cut -d' ' -f3`
	region=`echo $hostname |cut -d'.' -f3`
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
ConditionPathExists=!$root/cockroach_not_to_be_run

[Service]
WorkingDirectory=$root
ExecStart=$root/cockroach start --certs-dir=certs --store=path=data --host=$alias --locality=region=$region --join=$clist
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
	# -- install...
	scp -P 7422 -p -r \
		/opt/$arch_name \
		cockroach.service \
		cockroach.ufw \
		certs \
		hosts.dist \
		51.setup-cockroach-node.sh \
		$hostname:~/
	ssh -t -p 7422 $hostname "bash 51.setup-cockroach-node.sh"
done

# -- clean up
rm -rf certs cockroach.service cockroach.ufw hosts.dist
