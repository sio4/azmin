#!/bin/bash
#
# setup script for cockroach cluster
# https://www.cockroachlabs.com/docs/stable/install-cockroachdb.html

# -- get node list from /etc/hosts
nodes=`grep store- /etc/hosts`
mode=$@

[ "$mode" = "" ] && {
	echo "usage: $0 start|stop"
	exit
}

OIFS=$IFS
IFS=$'\n'
for node in $nodes; do
	addr=`echo $node |sed 's/\s/ /g' |cut -d' ' -f1`
	hostname=`echo $node |sed 's/\s/ /g' |cut -d' ' -f2`
	alias=`echo $node |sed 's/\s/ /g' |cut -d' ' -f3`
	echo "$mode cockroach on $alias ($hostname, $addr)"
	ssh -t -p 7422 $hostname "sudo systemctl -l --no-pager $mode cockroach"
done
