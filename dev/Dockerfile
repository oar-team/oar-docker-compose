FROM debian:bullseye as base

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN echo node > /etc/role

RUN apt-get update \
    && apt-get install -y systemd systemd-sysv \
    vim bash-completion apt-transport-https \
    ca-certificates psmisc openssh-client curl wget iptables socat pciutils \
    nmap locales net-tools iproute2 net-tools perl perl-base \
    taktuk libdbi-perl libsort-versions-perl libdbd-pg-perl\
    make gcc \
    postgresql-client inetutils-ping git tmux openssh-server netcat \
    procps libdatetime-perl libterm-ui-perl rsync socat \
    python3 python3-dev python3-pip python3-psycopg2 \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Intsall poetry at /root/.poetry/bin/poetry
# The install script writes to .profile, but this file is not read when be open a shell so I use the full path to poetry
RUN curl -sSL https://raw.githubusercontent.com/python-poetry/poetry/master/get-poetry.py | python3 -

COPY common /common
RUN chmod +x /common/*.sh

# Get access to python
RUN ln -s /usr/bin/python3 /usr/bin/python

RUN /common/create_users.sh && /common/generate_ssh_keys.sh

RUN rm -f /lib/systemd/system/multi-user.target.wants/* \
    /etc/systemd/system/*.wants/* \
    /lib/systemd/system/local-fs.target.wants/* \
    /lib/systemd/system/sockets.target.wants/*udev* \
    /lib/systemd/system/sockets.target.wants/*initctl* \
    /lib/systemd/system/sysinit.target.wants/systemd-tmpfiles-setup* \
    /lib/systemd/system/systemd-update-utmp*

RUN echo "DefaultTimeoutStartSec=5s" >> /etc/systemd/system.conf \
    && echo "DefaultTimeoutStopSec=5s" >> /etc/systemd/system.conf

RUN cp /common/oardocker-provision.service /etc/systemd/system/ \
    && systemctl enable oardocker-provision.service

VOLUME [ "/sys/fs/cgroup" ]

CMD ["/lib/systemd/systemd"]

# I would like to intsall that only on server, but poetry installs
# psycopg2 needed for oar, and it needs libpq-dev and postgresql-contrib.
RUN apt-get update \
    && apt-get install -y postgresql libpq-dev postgresql-contrib libjson-perl \
    taktuk \
    && apt-get clean

FROM base as server

RUN echo server > /etc/role

RUN postgresql_main=$(find /etc/postgresql -name "main") \
    && sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${postgresql_main}/postgresql.conf \
    && echo "host all all 0.0.0.0/0 md5" >> ${postgresql_main}/pg_hba.conf

RUN systemctl enable postgresql

CMD ["/lib/systemd/systemd"]

FROM base as node
RUN echo node > /etc/role

COPY /common/oardocker-cgroup.service /etc/systemd/system/oardocker-cgroup.service
COPY /common/prepare_oar_cgroup.sh /var/lib/container/init-scripts/prepare_oar_cgroup.sh

RUN systemctl enable oardocker-cgroup

CMD ["/lib/systemd/systemd"]

# Frontend TODO
FROM base as frontend
RUN echo frontend > /etc/role

RUN apt-get update \
   && apt-get install -y libsort-naturally-perl libjson-perl libyaml-perl \
   libappconfig-perl libtie-ixhash-perl libwww-perl libcgi-fast-perl \
   libapache2-mod-fcgid php php-fpm libapache2-mod-php php-pgsql \
   libjs-jquery php-apcu spawn-fcgi fcgiwrap \
   apache2 libapache2-mod-php \
   apache2-dev # Needed for mod_wsgi \
   && apt-get clean

#RUN apt-get install -y oar-web-status oar-user oar-user-pgsql oar-common \
#    && apt-get clean

#COPY --chown=oar:oar oar.conf /etc/oar/oar.conf
#COPY --chown=oar:oar --from=server /var/lib/oar/.ssh /var/lib/oar/.ssh

# Monika congiuration 
#RUN a2enmod cgi \
#    && sed -e "s/^\(hostname = \).*/\1server/" -i /etc/oar/monika.conf

# Drawgantt configuration 
#RUN sed -i "s/\$CONF\['db_server'\]=\"127.0.0.1\"/\$CONF\['db_server'\]=\"server\"/" /etc/oar/drawgantt-config.inc.php

CMD ["/lib/systemd/systemd"]
