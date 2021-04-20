FROM debian:buster as base

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
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

COPY common /common
RUN chmod +x /common/*.sh

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

FROM base as server

RUN echo server > /etc/role

RUN apt-get update \
    && apt-get install -y postgresql libjson-perl \
    taktuk \
    && apt-get clean

RUN postgresql_main=$(find /etc/postgresql -name "main") \
    && sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${postgresql_main}/postgresql.conf \
    && echo "host all all 0.0.0.0/0 md5" >> ${postgresql_main}/pg_hba.conf

RUN systemctl enable postgresql

CMD ["/lib/systemd/systemd"]

FROM base as node
RUN echo node > /etc/role

CMD ["/lib/systemd/systemd"]

# Frontend TODO
FROM base as frontend
RUN echo frontend > /etc/role

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
