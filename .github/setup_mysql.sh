#!/bin/bash

set -exo pipefail

MYSQL="mysql:8.0.35"
tries=0

sudo service mysql stop

docker pull ${MYSQL}

docker run -itd \
    --name=mysqld \
    -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
    -p 3306:3306 \
    ${MYSQL} \
    --default-authentication-plugin=mysql_native_password

while ! docker exec mysqld mysqladmin ping --host localhost --silent &> /dev/null ; do
    echo "Waiting for database connection..."
    sleep 2
    ((tries += 1))
    if [ $tries -gt 15 ]
    then
        exit 2
    fi
done
