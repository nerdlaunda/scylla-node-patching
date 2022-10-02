#!/bin/bash

IP=$(curl http://169.254.169.254/latest/meta-data/local-ipv4)
STATUS=$(nodetool status | grep $IP | awk '{print $1}')
##### Drain #####
echo "[Stage] >>> status check and drain"
nodetool status

if [ $STATUS == "UN" ]
    then
        echo ">>> Targetted node status is up and connected. Continue..."
        echo "[Stage] >>> Drain"
        nodetool drain
        if [ $? -ne 0 ]
            then
                echo ">>> nodetool drain is not successful. Quitting..."
                exit 1
        fi
        sleep 30
        STATUS=$(nodetool status | grep $IP | awk '{print $1}')
        if [ $STATUS != "UN" ]
            then
                systemctl is-active --quiet scylla-server
                if [ $? -eq 0 ]
                    then
                        systemctl stop scylla-server --quiet
                        if [ $? -ne 0 ]
                            then
                                echo ">>> Unable to stop scylla-server. Quitting..."
                                exit 1
                        fi
                fi
                systemctl disable scylla-server --quiet
                if [ $? -ne 0 ]
                    then
                        echo ">>> Unable to disable scylla-server. Quitting..."
                        exit 1
                    else
                        echo ">>> scylla-server is stopped and disabled."
                fi
        fi
fi

##### Yum update #####
echo "[Stage] >>> Yum update"
systemctl is-active --quiet scylla-server
if [ $? -eq 0 ]
    then
        echo ">>> Scylla service is still running. Quitting..."
        exit 1
fi
yum check-updates --exclude=*scylla* > /dev/null 2>&1
if [ $? == 100 ]
    then
        echo ">>> Package update(s) are available."
        echo ">>> Starting yum update (except scylla)"
        /usr/bin/yum update --exclude=*scylla* -y
    else
        echo ">>> All packages are up-to-date - No action required"
fi

needs-restarting -r > /dev/null 2>&1
if [ $? == 1 ]
    then
        echo ">>> Reboot required. Restarting"
        exit 194
fi

##### Old Kernal removal #####
TOTAL_KERNEL=$(rpm -qa kernel | wc -l)

if [ $TOTAL_KERNEL -gt 1 ]
    then
        package-cleanup --oldkernels --count=1 -y
fi

needs-restarting -r > /dev/null 2>&1
if [ $? == 1 ]
    then
        echo ">>> Reboot required"
        exit 194
fi

##### Start scylla-server #####
systemctl start scylla-server --quiet
systemctl is-active --quiet scylla-server
if [ $? -ne 0 ]
    then
        echo ">>> scylla-server service is not running."
    else
        echo ">>> Scylla-server service is running."
fi
sleep 30
STATUS=$(nodetool status | grep $IP | awk '{print $1}')
if [ $STATUS == "UN" ]
    then
        echo "Targetted node status is up and connected. Starting repair..."
    else
        echo "Link is down. Quitting..."
        exit 1
fi

##### Scylla reapir #####
nodetool repair
if [ $? -eq 0 ]
    then
        echo "Nodetool repair is successful."
    else
        echo "Repair job is not complete. Quitting..."
fi

##### Enable scylla-server#####
systemctl enable scylla-server
if [ $? -eq 0 ]
    then
        echo "Scylla server service is enabled. Patching operations completed. Success."
    else
        echo "Error. Quitting..."
fi
