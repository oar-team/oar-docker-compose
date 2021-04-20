#!/bin/bash
set -ue

trap 'echo trap signal TERM' 15 # HUP INT QUIT PIPE TERM

log_install="/log_install"

role=$(cat /etc/role)

if [ ! -f /oar_provisioned ]; then
    if [ "$role" == "server" ]
    then
        echo "Provision OAR Server"
        /common/oar2-server-install.sh >> $log_install || echo "oar2-server-install exit $?"
        #/common/oar2-server-install.sh >> $log_install || (echo "oar2-server-install exit $?" | tee >> $log_install)

        oar-database --create --db-is-local
        systemctl enable oar-server
        systemctl start oar-server
        
        oarnodesetting -a -h node1
        oarnodesetting -a -h node2
    elif  [ "$role" == "node" ]
    then
        echo "Provision OAR Node"
        bash /common/oar2-node-install.sh >> $log_install || echo "oar2-node-install exit $?"
        systemctl enable oar-node
        systemctl start oar-node 
        
    elif  [ "$role" == "frontend" ]
    then
        echo "Provision OAR Frontend"
        /common/oar2-frontend-install.sh >> $log_install || echo "oar2-frontend-install exit $?"
    else
        echo "Unkown or undefined role: $role"
    fi
    touch /oar_provisioned
    
else
    echo "Already OAR provisioned !"
fi    
