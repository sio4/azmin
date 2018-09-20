#!/bin/bash
#
# backup script for system wide configurations and important files
# linked as /etc/cron.daily/backup

files="
/home/azmin/admin
/home/azmin/setup
/etc/hosts
"

date=`date +%Y%m%d_%H%M%S`

tar jcf files.$date.tbz $files
