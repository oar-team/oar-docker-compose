#!/bin/bash
set -ue

fail() {
    echo $@ 1>&2
    exit 1
}

if [ $# -eq 0 ]
  then
      fail "No arguments supplied"
fi

SRCDIR=$1
VERSION_MAJOR=${2:-3}

if (( VERSION_MAJOR==3 )); then
    cd $SRCDIR && /root/.poetry/bin/poetry install
    # pip3 install $SRCDIR/dist/*.whl
    OARDIR=$(~/.poetry/bin/poetry env list --full-path)
fi

# Install OAR server
make -C $SRCDIR PREFIX=/usr/local server-build
make -C $SRCDIR PREFIX=/usr/local server-install
make -C $SRCDIR PREFIX=/usr/local server-setup

# Install OAR user cli (oarnodes, oarstat ...)
make -C $SRCDIR PREFIX=/usr/local user-build
make -C $SRCDIR PREFIX=/usr/local user-install 
make -C $SRCDIR PREFIX=/usr/local user-setup 

# Copy initd scripts
if [ -f /usr/local/share/oar/oar-server/init.d/oar-server ]; then
    cat /usr/local/share/oar/oar-server/init.d/oar-server > /etc/init.d/oar-server
    chmod +x  /etc/init.d/oar-server
fi

if [ -f /usr/local/share/oar/oar-server/default/oar-server ]; then
    cat /usr/local/share/oar/oar-server/default/oar-server > /etc/default/oar-server
fi

#if [ -f /usr/local/share/oar/oar-server/job_resource_manager_cgroups.pl ]; then
#    ln -sf /usr/local/share/oar/oar-server/job_resource_manager_cgroups.pl /etc/oar/job_resource_manager_cgroups.pl
#fi
if (( VERSION_MAJOR==3 )); then
    cp /srv/common/oar3.conf /etc/oar/oar.conf
else
    cp /srv/common/oar2.conf /etc/oar/oar.conf
fi

chown oar:oar /etc/oar/oar.conf
chmod 600 /etc/oar/oar.conf

# OAR SSH KEYS the same for all nodes 
/common/configure_oar_ssh_keys.sh

## the script provided by oar-2.5.8 failed w/ docker-compose 
cp /common/job_resource_manager_cgroups.pl /etc/oar/job_resource_manager_cgroups.pl
