#!/bin/bash
set -ue

if [ ! -f /oar_provisioned ]; then

    oar-database --create --db-is-local
    
    systemctl enable oar-server
    systemctl start oar-server
    
    oarnodesetting -a -h node1
    oarnodesetting -a -h node2
    touch /oar_provisioned
    
else
    echo "Already OAR provisioned !"
fi    
