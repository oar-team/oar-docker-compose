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
    cd $SRCDIR && /root/.poetry/bin/poetry build
    pip3 install $SRCDIR/dist/*.whl
fi

# Install OAR
make -C $SRCDIR PREFIX=/usr/local node-build
make -C $SRCDIR PREFIX=/usr/local node-install
make -C $SRCDIR PREFIX=/usr/local node-setup

# Install OAR user cli (oarnodes, oarstat ...)
#make -C $SRCDIR PREFIX=/usr/local user-build
#make -C $SRCDIR PREFIX=/usr/local user-install 
#make -C $SRCDIR PREFIX=/usr/local user-setup 

# Copy initd scripts
if [ -f /usr/local/share/oar/oar-node/init.d/oar-node ]; then
    cat /usr/local/share/oar/oar-node/init.d/oar-node > /etc/init.d/oar-node
    chmod +x  /etc/init.d/oar-node
fi

if [ -f /usr/local/share/oar/oar-node/default/oar-node ]; then
    cat /usr/local/share/oar/oar-node/default/oar-node > /etc/default/oar-node
fi

if (( VERSION_MAJOR==3 )); then
    cp /srv/common/oar3.conf /etc/oar/oar.conf
else
    cp /srv/common/oar2.conf /etc/oar/oar.conf
fi

chown oar:oar /etc/oar/oar.conf
chmod 600 /etc/oar/oar.conf

# OAR SSH KEYS the same for all nodes 
/common/configure_oar_ssh_keys.sh
