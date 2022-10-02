#!/bin/bash
echo "[Stage] >>> Check update"
yum check-updates --exclude=*scylla* > /dev/null 2>&1
if [ $? != 100 ]
    then
        echo "All packages are up-to-date - No action required"
        exit 1
fi
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
STATUS=$(nodetool status | grep $IP | awk '{print $1}')
echo "[Stage] >>> status check"
if [ $STATUS == "UN" ]
    then
        echo ">>> Targetted node status is up and connected. Continue..."
    else
        echo ">>> Targetted node is disconnected. Quitting..."
        exit 1
fi
echo "[Stage] >>> Drain"
nodetool drain
if [ $? -ne 0 ]
    then
        echo ">>> nodetool drain is not successful. Quitting..."
        exit 1
fi
STATUS=$(nodetool status | grep $IP | awk '{print $1}')
if [ $STATUS == "UN" ]
    then
        echo ">>> Targetted node status is still up and connected. Quitting..."
        exit 1
fi
echo "[Stage] >>> Stop scylla-server"
systemctl is-active --quiet scylla-server
if [ $? -ne 0 ]
    then
        echo "scylla-server service is not running. Quitting..."
        exit 1
fi
systemctl stop scylla-server
if [ $? -ne 0 ]
    then
        echo ">>> Unable to stop scylla-server. Quitting..."
        exit 1
fi
systemctl is-active --quiet scylla-server
if [ $? -eq 0 ]
    then
        echo "scylla-server service is still running. Quitting..."
        exit 1
fi
echo "[Stage] >>> Yum update"
/usr/bin/yum update --exclude=*scylla* -y
needs-restarting -r > /dev/null 2>&1
if [ $? == 1 ]
    then
        echo "Reboot required"
        exit 194
        #reboot
fi
TOTAL_KERNEL=$(rpm -qa kernel | wc -l)
if [ $TOTAL_KERNEL -gt 1 ]
    then
        package-cleanup --oldkernels --count=1 -y
fi
needs-restarting -r > /dev/null 2>&1
if [ $? == 1 ]
    then
        echo "Reboot required"
        exit 194
        #reboot
fi
systemctl start scylla-server
systemctl is-active --quiet scylla-server
if [ $? -ne 0 ]
    then
        echo "scylla-server service is not running."
        exit 1
fi
IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
STATUS=$(nodetool status | grep $IP | awk '{print $1}')
if [ $STATUS != "UN" ]
    then
        echo "Targetted node link is down. Quitting..."
        exit 1
fi
nodetool repair
if [ $? -eq 0 ]
    then
        echo "Nodetool is successful. Patching complete. Quitting..."
    else
        echo "Repair job is not complete. Quitting..."
fi