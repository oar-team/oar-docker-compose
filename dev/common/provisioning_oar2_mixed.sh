#!/bin/bash
# Bash script performing a working installation of oar2. Bat that also intalls oar3.

set -uex

trap 'echo trap signal TERM' 15 # HUP INT QUIT PIPE TERM

log="/log_provisioning"

if [ -f "/srv/.env_oar_provisoning.sh" ]; then
    source /srv/.env_oar_provisoning.sh
fi

: ''${AUTO_PROVISIONING=1}
: ''${SRC:=""}

: ''${FRONTEND_OAREXEC=false}
: ''${SRC_OAR3=""}
#: ''${TARBALL:=""}
: ''${TARBALL:="https://github.com/oar-team/oar/archive/refs/heads/master.tar.gz"}
: ''${TARBALL_OAR3:="https://github.com/oar-team/oar3/archive/refs/heads/master.tar.gz"}

if (( $AUTO_PROVISIONING==0 )); then
    echo "AUTO_PROVISIONING disabled" >> $log
    exit 0
fi

IFS='.' read DEBIAN_VERSION DEBIAN_VERSION_MINOR < /etc/debian_version

# Mixed provision installs oar2
VERSION_MAJOR=2

TMPDIR=$(mktemp -d --tmpdir install_oar.XXXXXXXX)
SRCDIR="$TMPDIR/src"
SRCDIR_OAR3="$TMPDIR/src_oar3"

mkdir -p $SRCDIR
mkdir -p $SRCDIR_OAR3

on_exit() {
    mountpoint -q $SRCDIR && umount $SRCDIR || true
    mountpoint -q $SRCDIR_OAR3 && umount $SRCDIR_OAR3 || true
    # rm -rf $TMPDIR
}

trap "{ on_exit; kill 0; }" EXIT

fail() {
    echo $@ 1>&2
    echo $@ >> $log
    exit 1
}

# Copy oar2 sources
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

# Copy oar3 files
if [ -z "$SRC_OAR3" ]; then
    echo "TARBALL OAR3: $TARBALL_OAR3" >> $log

    [ -n "$TARBALL_OAR3" ] || fail "error: You must provide a URL to a OAR tarball"

    if [ ! -r "$TARBALL_OAR3" ]; then
        curl -L $TARBALL_OAR3 -o $TMPDIR/oar-tarball.tar.gz
        TARBALL_OAR3=$TMPDIR/oar-tarball.tar.gz
    else
        TARBALL_OAR3="$(readlink -m $TARBALL_OAR3)"
    fi

    VERSION=$(echo $TARBALL_OAR3 | rev | cut -d / -f1 | rev | cut -d "." -f1)
    SRCDIR_OAR3=$SRCDIR_OAR3/oar-${VERSION}
    mkdir $SRCDIR_OAR3 && tar xf $TARBALL_OAR3 -C $SRCDIR_OAR3 --strip-components 1
else
    SRC_OAR3=/srv/$SRC_OAR3
    if [ -d $SRC_OAR3 ]; then
        SRCDIR_OAR3=$SRCDIR_OAR3/src
        mkdir $SRCDIR_OAR3 && cp -a $SRC_OAR3/* $SRCDIR_OAR3
    else
        fail "error: Directory $SRC does not exist"
        exit 1
    fi
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

    # Install OAR3 sources to install the oar3's scheduler
    cd $SRCDIR_OAR3 && /root/.poetry/bin/poetry build
    pip3 install $SRCDIR_OAR3/dist/*.whl

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
