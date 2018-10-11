#!/bin/bash
#
# certificates update script for cockroach cluster

set -e

# -- get node list from /etc/hosts
nodes=`grep crdb- /etc/hosts`


# -- installation structure
root="/opt/cockroach"
bin="$root/cockroach"


# -- create certifications
if [ ! -e "keys/ca.key" ]; then
	$bin cert create-ca --certs-dir=$root/certs --ca-key=keys/ca.key
fi
if [ ! -e "$root/certs/ca.crt" ]; then
	$bin cert create-client root --certs-dir=$root/certs --ca-key=keys/ca.key
fi


# -- preparing files
mkdir -p certs
cp -a $root/certs/ca.crt certs


# -- install cockroach to nodes...
OIFS=$IFS
IFS=$'\n'
for node in $nodes; do
	addr=`echo $node |sed 's/\s/ /g' |cut -d' ' -f1`
	hostname=`echo $node |sed 's/\s/ /g' |cut -d' ' -f2`
	alias=`echo $node |sed 's/\s/ /g' |cut -d' ' -f3`
	echo
	echo "update certificates for $alias ($hostname, $addr)"

	$bin cert create-node \
		localhost $hostname $alias $addr $LB_NAME $LB_ADDR \
		--certs-dir=certs --ca-key=keys/ca.key \
		--overwrite
	# -- install...
	scp -P 7422 -p -r \
		certs/* \
		$hostname:$root/certs/
	ssh -t -p 7422 $hostname "sudo systemctl reload cockroach" || true
done


# -- clean up
rm -rf certs
