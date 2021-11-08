#!/bin/bash
set -uex

trap 'echo trap signal TERM' 15 # HUP INT QUIT PIPE TERM

log="/log_provisioning"

if [ -f "/srv/.env_oar_provisoning.sh" ]; then
    source /srv/.env_oar_provisoning.sh
fi

: ''${AUTO_PROVISIONING=1}
: ''${SRC:=""}
: ''${FRONTEND_OAREXEC=false}
: ''${MIXED_INSTALL=false}
#: ''${TARBALL:=""}
: ''${TARBALL:="https://github.com/oar-team/oar3/archive/refs/heads/master.tar.gz"}

if (( $AUTO_PROVISIONING==0 )); then
    echo "AUTO_PROVISIONING disabled" >> $log
    exit 0
fi

IFS='.' read DEBIAN_VERSION DEBIAN_VERSION_MINOR < /etc/debian_version

TMPDIR=$(mktemp -d --tmpdir install_oar.XXXXXXXX)
SRCDIR="$TMPDIR/src"

mkdir -p $SRCDIR

on_exit() {
    mountpoint -q $SRCDIR && umount $SRCDIR || true
    rm -rf $TMPDIR
}

trap "{ on_exit; kill 0; }" EXIT

fail() {
    echo $@ 1>&2
    echo $@ >> $log
    exit 1
}


if [ ! -f /oar_provisioned ]; then

    if [ $MIXED_INSTALL = true ]; then
        echo "Provisioning mixed installation"
        exec bash /common/provisioning_oar2_mixed.sh
        echo "fail exec"
        exit 1
    fi

    if [ -z $SRC ]; then
        echo "TARBALL: $TARBALL" >> $log

        [ -n "$TARBALL" ] || fail "error: You must provide a URL to a OAR tarball"
        if [ ! -r "$TARBALL" ]; then
            curl -L $TARBALL -o $TMPDIR/oar-tarball.tar.gz
            TARBALL=$TMPDIR/oar-tarball.tar.gz
        else
            TARBALL="$(readlink -m $TARBALL)"
        fi

        VERSION=$(echo $TARBALL | rev | cut -d / -f1 | rev | cut -d "." -f1)
        SRCDIR=$SRCDIR/oar-${VERSION}
        mkdir $SRCDIR && tar xf $TARBALL -C $SRCDIR --strip-components 1
    else
        SRC=/srv/$SRC
        if [ -d $SRC ]; then
            SRCDIR=$SRCDIR/src
            mkdir $SRCDIR && cp -a $SRC/* $SRCDIR
        else
            fail "error: Directory $SRC does not exist"
            exit 1
        fi
    fi

    if [ -e $SRCDIR/oar/__init__.py ]; then
        VERSION_MAJOR=3
    else
        VERSION_MAJOR=2
    fi

    role=$(cat /etc/role)

    if [ "$role" == "server" ]
    then
        echo "Provisioning OAR Server" >> $log
        /common/oar-server-install.sh $SRCDIR $VERSION_MAJOR >> $log || fail "oar-server-install exit $?"
        oar-database --create --db-is-local
        systemctl enable oar-server
        systemctl start oar-server
        
        oarnodesetting -a -h node1
        oarnodesetting -a -h node2
    elif [ "$role" == "node" ] || [[ $FRONTEND_OAREXEC = true && "$role" == "frontend" ]];
    then
        echo "Provision OAR Node for $role"
        bash /common/oar-node-install.sh $SRCDIR $VERSION_MAJOR >> $log || fail "oar-node-install exit $?"
        systemctl enable oar-node
        systemctl start oar-node
    fi

    if  [ "$role" == "frontend" ]
    then
        echo "Provisioning OAR Frontend" >> $log
        /common/oar-frontend-install.sh $SRCDIR $VERSION_MAJOR >> $log || fail "oar-frontend-install exit $?"
    fi

    touch /oar_provisioned

else
    echo "Already OAR provisioned !" >> $log
fi
