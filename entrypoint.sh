#!/bin/bash

cp /etc/resolv.conf /var/spool/postfix/etc/resolv.conf
cp -f /etc/services /var/spool/postfix/etc/services

pg_host=${POSTGRES_HOST-}
pg_user=${POSTGRES_USER-}
pg_password=${POSTGRES_PASSWORD-}
pg_db=${POSTGRES_DB-}

if [ -z ${pg_host} ];
then
  echo "ERROR: POSTGRES_HOST unset";
  exit
fi
if [ -z ${pg_user} ];
then
  echo "ERROR: POSTGRES_USER unset";
  exit
fi
if [ -z ${pg_password} ];
then
  echo "ERROR: POSTGRES_PASSWORD unset";
  exit
fi
if [ -z ${pg_db} ];
then
  echo "ERROR: POSTGRES_DB unset";
  exit
fi

hostname=${HOSTNAME-}
email_domain=${EMAIL_DOMAIN-}

if [ -z ${hostname} ];
then
  echo "ERROR: HOSTNAME unset";
  exit
fi
if [ -z ${email_domain} ];
then
  echo "ERROR: EMAIL_DOMAIN unset";
  exit
fi

tls_cert_file=${TLS_CERT_FILE-}
tls_cert_key=${TLS_CERT_KEY-}
# escape slashes in tls_cert_file and tls_cert_key
tls_cert_file=${tls_cert_file//\//\\\/}
tls_cert_key=${tls_cert_key//\//\\\/}

if [ -z ${tls_cert_file} ];
then
  echo "ERROR: TLS_CERT_FILE unset";
  exit
fi
if [ -z ${tls_cert_key} ];
then
  echo "ERROR: TLS_CERT_KEY unset";
  exit
fi

echo "creating postfix configs"

sed -i "s/{HOSTNAME}/$hostname/" /etc/postfix/main.cf
sed -i "s/{EMAIL_DOMAIN}/$email_domain/" /etc/postfix/main.cf
sed -i "s/{TLS_CERT_FILE}/$tls_cert_file/" /etc/postfix/main.cf
sed -i "s/{TLS_CERT_KEY}/$tls_cert_key/" /etc/postfix/main.cf

sed -i "s/{POSTGRES_HOST}/$pg_host/" /etc/postfix/pgsql-relay-domains.cf
sed -i "s/{POSTGRES_USER}/$pg_user/" /etc/postfix/pgsql-relay-domains.cf
sed -i "s/{POSTGRES_PASSWORD}/$pg_password/" /etc/postfix/pgsql-relay-domains.cf
sed -i "s/{POSTGRES_DB}/$pg_db/" /etc/postfix/pgsql-relay-domains.cf
sed -i "s/{EMAIL_DOMAIN}/$email_domain/" /etc/postfix/pgsql-relay-domains.cf

sed -i "s/{POSTGRES_HOST}/$pg_host/" /etc/postfix/pgsql-transport-maps.cf
sed -i "s/{POSTGRES_USER}/$pg_user/" /etc/postfix/pgsql-transport-maps.cf
sed -i "s/{POSTGRES_PASSWORD}/$pg_password/" /etc/postfix/pgsql-transport-maps.cf
sed -i "s/{POSTGRES_DB}/$pg_db/" /etc/postfix/pgsql-transport-maps.cf
sed -i "s/{EMAIL_DOMAIN}/$email_domain/" /etc/postfix/pgsql-transport-maps.cf

echo "waiting for postgres to be ready..."
while ! nc -z ${POSTGRES_HOST} ${POSTGRES_PORT:-5432}; do
  echo "waiting for postgres to be ready..."
  sleep 3
done

# upgrade db models
DB_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}/${POSTGRES_DB} alembic upgrade head
DB_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}/${POSTGRES_DB} python init_app.py

# create empty postfix aliases
touch /etc/aliases && postalias /etc/aliases

echo "starting simplelogin"
DB_URI=postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_HOST}:${POSTGRES_PORT:-5432}/${POSTGRES_DB} /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
