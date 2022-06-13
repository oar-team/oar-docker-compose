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
: ''${LIVE_RELOAD=false}
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
    # rm -rf $TMPDIR
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

        if [ $LIVE_RELOAD = true ]; then
            echo "Activate live reload"

            # Names can be confuging. SRCDIR is the folder (on your laptop) containing the oar3 sources.
            echo "SRCDIR=$SRC" > /etc/.test
            # TMPDIR is a folder inside the docker used to avoid conflicts between the containers (node1,2, frontend, server)
            echo "TMPDIR=$SRCDIR" >> /etc/.test

            cat /srv/common/live-reload.service > /etc/systemd/system/live-reload.service
            systemctl enable live-reload
            # Starting the service here could conflicts wit the following of this script
            # which will also install oar3.
            # But as long as the oar3 folder is not modified it should not be triggered.
            systemctl start live-reload
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
        /srv/common/oar-server-install.sh $SRCDIR $VERSION_MAJOR >> $log || fail "oar-server-install exit $?"
        oar-database --create --db-is-local
        systemctl enable oar-server
        systemctl start oar-server

        #source /etc/systemd/system/create_resources.sh
        #create_resources_manually

        oarproperty -a cpu || true
        oarproperty -a core || true
        oarproperty -c -a host || true
        oarproperty -a mem || true

        nodes=$NODES
        cpus=$CPUS
        cores=$(grep -e "^processor\s\+:" /proc/cpuinfo | sort -u | wc -l)
        mem=$(grep -e "^MemTotal" /proc/meminfo | awk '{print $2}')
        mem=$((mem / 1024 / 1024 + 1))

        totalcores=$((cores*cpus*nodes))

        node=0
        cpu=0
        node=0
        for ((core=1;core<=$totalcores; core++)); do

            if (((core-1)%(cpus*cores)==0)); then
                node=$((node + 1))
            fi

            if (((core-1)%cores==0)); then
                cpu=$((cpu + 1))
            fi

            echo $node $cpu $core $(((core-1)%cores)) >> $log
            oarnodesetting -a -h "dev_node_"$node -p host="dev_node_"$node -p cpu=$cpu -p core=$core -p cpuset=$(((core-1)%cores)) -p mem=$mem &
            wait
        done

        node=0
        cpu=0
        node=0
        for ((core=1;core<=$totalcores; core++)); do

            if (((core-1)%(cpus*cores)==0)); then
                node=$((node + 1))
            fi

            if (((core-1)%cores==0)); then
                cpu=$((cpu + 1))
            fi

            echo $node $cpu $core $(((core-1)%cores)) >> $log
            oarnodesetting -r $core -p "cpu=$cpu" -p "core=$core" -p "cpuset=$(((core-1)%cores))" -p mem=$mem &
            wait
        done

    elif [ "$role" == "node" ] || [[ $FRONTEND_OAREXEC = true && "$role" == "frontend" ]];
    then
        echo "Provision OAR Node for $role"
        bash /srv/common/oar-node-install.sh $SRCDIR $VERSION_MAJOR >> $log || fail "oar-node-install exit $?"
        systemctl enable oar-node
        systemctl start oar-node
    fi

    if  [ "$role" == "frontend" ]
    then
        echo "Provisioning OAR Frontend" >> $log
        /srv/common/oar-frontend-install.sh $SRCDIR $VERSION_MAJOR >> $log || fail "oar-frontend-install exit $?"
    fi

    touch /oar_provisioned

else
    echo "Already OAR provisioned !" >> $log
fi
