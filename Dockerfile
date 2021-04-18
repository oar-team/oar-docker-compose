FROM debian:buster as base

ENV container docker
ENV LC_ALL C
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
    && apt-get install -y systemd systemd-sysv \
    bash-completion \
    nano \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/* \

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

RUN apt-get update \
    && apt-get install -y oar-server oar-server-pgsql oar-user oar-user-pgsql postgresql libjson-perl \
    taktuk \
    && apt-get clean

# Import oar.conf
COPY --chown=oar:oar oar.conf /etc/oar/oar.conf
# Import resource_manager_cgroups.pl (TOREMOVE)
COPY --chown=oar:oar job_resource_manager_cgroups.pl /etc/oar/job_resource_manager_cgroups.pl

COPY common /common

RUN postgresql_main=$(find /etc/postgresql -name "main") \
    && sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" ${postgresql_main}/postgresql.conf \
    && echo "host all all 0.0.0.0/0 md5" >> ${postgresql_main}/pg_hba.conf

# Disable oar-server before provisioning
RUN systemctl disable oar-server
RUN systemctl enable postgresql

CMD ["/lib/systemd/systemd"]

FROM base as node

RUN apt-get update \
    && apt-get install -y oar-node

COPY --chown=oar:oar oar.conf /etc/oar/oar.conf

# copy oar keys from server 
COPY --chown=oar:oar --from=server /var/lib/oar/.ssh /var/lib/oar/.ssh
#RUN chown -R oar:oar /var/lib/oar/.ssh
