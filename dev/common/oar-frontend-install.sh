#!/bin/bash
set -uex

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

TOOLS_BUILD=""
TOOLS_INSTALL=""
TOOLS_SETUP=""

if (( VERSION_MAJOR==3 )); then
    cd $SRCDIR && POETRY_VIRTUALENVS_CREATE=false /root/.poetry/bin/poetry install
    # pip3 install $SRCDIR/dist/*.whl
    OARDIR=$(~/.poetry/bin/poetry env list --full-path)
else
    TOOLS_BUILD="tools-build"
    TOOLS_INSTALL="tools-install"
    TOOLS_SETUP="tools-setup"
fi

# Install OAR
make -C $SRCDIR PREFIX=/usr/local user-build $TOOLS_BUILD node-build
make -C $SRCDIR PREFIX=/usr/local user-install drawgantt-svg-install monika-install www-conf-install api-install $TOOLS_INSTALL node-install
make -C $SRCDIR PREFIX=/usr/local user-setup drawgantt-svg-setup monika-setup www-conf-setup api-setup $TOOLS_SETUP node-setup

# Configure MOTD / TODO
#sed -i s/__OAR_VERSION__/${VERSION}/ /etc/motd
#chmod 644 /etc/motd

# Configure oar-node for cosystem/deploy jobs
# Copy initd scripts

if [ -f /usr/local/share/oar/oar-node/init.d/oar-node ]; then
    cat /usr/local/share/oar/oar-node/init.d/oar-node > /etc/init.d/oar-node
    chmod +x  /etc/init.d/oar-node
fi

if [ -f /usr/local/share/oar/oar-node/default/oar-node ]; then
    cat /usr/local/share/oar/oar-node/default/oar-node > /etc/default/oar-node
fi

# Configure OAR restful api for Apache2 TODO
a2enmod headers
a2enmod rewrite

rm -f /etc/oar/api-users
htpasswd -b -c /etc/oar/api-users docker docker
htpasswd -b /etc/oar/api-users oar oar
# sed -i -e '1s@^/var/www.*@/usr/local/lib/cgi-bin@' /etc/apache2/suexec/www-data
# a2enmod suexec
if [ $VERSION_MAJOR = "2" ]; then
    perl -i -pe 's/Require local/Require all granted/; s/#(ScriptAlias \/oarapi-priv)/$1/; $do=1 if /#<Location \/oarapi-priv>/; if ($do) { $do=0 if /#<\/Location>/; s/^#// }' /etc/oar/apache2/oar-restful-api.conf
else
    perl -i -pe 's/Require local/Require all granted/; $do=1 if /#<Location \/oarapi-priv>/; if ($do) { $do=0 if /#<\/Location>/; s/^#// }' /etc/oar/apache2/oar-restful-api.conf

    # Enable mod_wsgi
    # First install the mod with pip (official recommendations)
    (cd $SRCDIR && /root/.poetry/bin/poetry run pip install mod_wsgi)
    # mod_wsgi-express gives the configuration to put in the apache conf
    LOAD_WSGI_MODULE=$(cd $SRCDIR && /root/.poetry/bin/poetry run mod_wsgi-express module-config | grep LoadModule)
    LOAD_WSGI_HOME=$(cd $SRCDIR && /root/.poetry/bin/poetry run mod_wsgi-express module-config | grep WSGIPythonHome)
    # Make the root home accessible for mod_wsgi to load python environements containing oar lib
    chmod 777 -R /root
    # Rewrite configuration
    sed -i -e "s#%%LOAD_WSGI_MODULE%%#${LOAD_WSGI_MODULE}#" /etc/oar/apache2/oar-restful-api.conf
    sed -i -e "s#%%LOAD_WSGI_HOME%%#${LOAD_WSGI_HOME}#" /etc/oar/apache2/oar-restful-api.conf
fi
# Fix auth header for newer Apache versions
sed -i -e "s/E=X_REMOTE_IDENT:/E=HTTP_X_REMOTE_IDENT:/" /etc/oar/apache2/oar-restful-api.conf
a2enconf oar-restful-api

a2enmod cgi
# Change cgi-bin path to /usr/local
sed -i -e "s@/usr/lib/cgi-bin@/usr/local/lib/cgi-bin@" /etc/apache2/conf-available/serve-cgi-bin.conf

sed -e "s/^\(clustername = \).*/\1oardocker for OAR $VERSION_MAJOR/" -i /etc/oar/monika.conf
sed -e "s/^\(hostname = \).*/\1server/" -i /etc/oar/monika.conf
sed -e "s/^\(username.*\)oar.*/\1oar_ro/" -i /etc/oar/monika.conf
sed -e "s/^\(password.*\)oar.*/\1oar_ro/" -i /etc/oar/monika.conf
sed -e "s/^\(dbtype.*\)mysql.*/\1psql/" -i /etc/oar/monika.conf
sed -e "s/^\(dbport.*\)3306.*/\15432/" -i /etc/oar/monika.conf
sed -e "s/^\(hostname.*\)localhost.*/\1server/" -i /etc/oar/monika.conf
chown www-data /etc/oar/monika.conf

sed -i "s/\$CONF\['db_type'\]=\"mysql\"/\$CONF\['db_type'\]=\"pg\"/" /etc/oar/drawgantt-config.inc.php
sed -i "s/\$CONF\['db_server'\]=\"127.0.0.1\"/\$CONF\['db_server'\]=\"server\"/" /etc/oar/drawgantt-config.inc.php
sed -i "s/\$CONF\['db_port'\]=\"3306\"/\$CONF\['db_port'\]=\"5432\"/" /etc/oar/drawgantt-config.inc.php
sed -i "s/\"My OAR resources\"/\"oardocker resources for OAR $VERSION_MAJOR\"/" /etc/oar/drawgantt-config.inc.php
sed -i -e '/label_cmp_regex/!b;n;c\ \ '\''network_address'\'' => '\''/(\\d+)/'\'',' /etc/oar/drawgantt-config.inc.php

a2enconf oar-web-status

# Configure phppgadmin
#sed -i "s/\$conf\['extra_login_security'\] = true;/\$conf\['extra_login_security'\] = false;/g" /etc/phppgadmin/config.inc.php
#sed -i "s/\$conf\['servers'\]\[0\]\['host'\] = 'localhost';/\$conf\['servers'\]\[0\]\['host'\] = 'server';/g" /etc/phppgadmin/config.inc.php
#sed -i "s/Require local/Require all granted/" /etc/apache2/conf-available/phppgadmin.conf

systemctl restart apache2

if (( VERSION_MAJOR==3 )); then
    cp /srv/common/oar3.conf /etc/oar/oar.conf
else
    cp /srv/common/oar2.conf /etc/oar/oar.conf
fi

chown oar:oar /etc/oar/oar.conf
chmod 600 /etc/oar/oar.conf

# OAR SSH KEYS the same for all nodes 
/common/configure_oar_ssh_keys.sh
