FROM debian:bullseye as base

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y systemd systemd-sysv \
    bash-completion \
    nano \
    perl perl-base openssh-client \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

RUN echo "DefaultTimeoutStartSec=5s" >> /etc/systemd/system.conf \
    && echo "DefaultTimeoutStopSec=5s" >> /etc/systemd/system.conf

RUN useradd -m user1 -s /bin/bash \
    && useradd -m user2 -s /bin/bash

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/lib/systemd/systemd"]

FROM base as server

# Python dependencies for oar3
RUN apt-get update && \
    apt-get install -y python3 \
    python3-sqlalchemy python3-alembic \
    python3-click python3-flask \
    python3-passlib python3-psutil python3-requests \
    python3-simplejson python3-sqlalchemy-utils  \
    python3-tabulate python3-toml python3-yaml \
    python3-zmq python3-psycopg2

# Install procset
COPY packages/python3-procset_3.0.0~rc1-1_all.deb /common/
RUN dpkg -i /common/python3-procset_3.0.0~rc1-1_all.deb

RUN apt-get update \
    && apt-get install -y oar-server oar-server-pgsql oar-user oar-user-pgsql postgresql libjson-perl \
    taktuk \
    && apt-get clean

# Import oar.conf
COPY --chown=oar:oar oar.conf /etc/oar/oar.conf
COPY --chown=oar:oar job_resource_manager_cgroups.pl /etc/oar/job_resource_manager_cgroups.pl

RUN postgresql_main=$(find /etc/postgresql -name "main") \
    && sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${postgresql_main}/postgresql.conf \
    && echo "host all all 0.0.0.0/0 md5" >> ${postgresql_main}/pg_hba.conf

# Disable oar-server before provisioning
RUN systemctl disable oar-server
RUN systemctl enable postgresql

COPY prepare_oar_cgroup.sh /prepare_oar_cgroup.sh
COPY provisioning.sh /provisioning.sh

RUN chmod +x /*.sh

CMD ["/lib/systemd/systemd"]

FROM base as node

RUN apt-get update \
    && apt-get install -y oar-node

COPY --chown=oar:oar oar.conf /etc/oar/oar.conf
# copy oar keys from server
COPY --chown=oar:oar --from=server /var/lib/oar/.ssh /var/lib/oar/.ssh

FROM base as frontend

RUN apt-get update \
   && apt-get install -y libsort-naturally-perl libjson-perl libyaml-perl \
   libappconfig-perl libtie-ixhash-perl libwww-perl libcgi-fast-perl \
   libapache2-mod-fcgid php php-fpm libapache2-mod-php php-pgsql \
   libjs-jquery php-apcu spawn-fcgi fcgiwrap \
   apache2 libapache2-mod-php

RUN apt-get install -y oar-web-status oar-user oar-user-pgsql oar-common \
    && apt-get clean

COPY --chown=oar:oar oar.conf /etc/oar/oar.conf
COPY --chown=oar:oar --from=server /var/lib/oar/.ssh /var/lib/oar/.ssh

# Monika congiuration 
RUN a2enmod cgi \
    && sed -e "s/^\(hostname = \).*/\1server/" -i /etc/oar/monika.conf

# Drawgantt configuration 
RUN sed -i "s/\$CONF\['db_server'\]=\"127.0.0.1\"/\$CONF\['db_server'\]=\"server\"/" /etc/oar/drawgantt-config.inc.php

CMD ["/lib/systemd/systemd"]
