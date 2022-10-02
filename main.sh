#!/bin/bash

nodetool status

nodetool drain
if [ $? -ne 0]
    then 
        echo "nodetool drain is not successful. Quitting..."
        exit 1
fi

#sleep(60)
systemctl status scylla 
systemctl is-active --quiet scylla-server
if [ $? -ne 0 ]
    then
        echo "scylla-server service is not running. Quitting..."
        exit 1
fi

yum check-updates --exclude=*scylla* > /dev/null 2>&1
if [ $? == 100 ]
    then
        echo "Packsage update(s) are available."
        echo "Starting yum update (except scylla)"
        /usr/bin/yum update --exclude=*scylla* -y
    else
        echo "All packages are up-to-date - No action required"
fi

needs-restarting -r > /dev/null 2>&1

if [ $? == 1 ]
    then
        echo "Reboot required"
        # exit 194
        reboot
fi

TOTAL_KERNEL = $(rpm -qa kernel | wc -l)

if [ $TOTAL_KERNEL -gt 1]
    then 
        package-cleanup --oldkernels --count=1
fi

needs-restarting -r > /dev/null 2>&1

if [ $? == 1 ]
    then
        echo "Reboot required"
        # exit 194
        reboot
fi