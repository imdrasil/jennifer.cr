#!/bin/bash

set -exo pipefail

old_mysql_setup()
{
    # Install newer MySQL
    sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com A4A9406876FCBD3C456770C88C718D3B5072E1F5
    wget http://dev.mysql.com/get/mysql-apt-config_0.8.1-1_all.deb
    sudo dpkg -i mysql-apt-config_0.8.10-1_all.deb
    sudo apt-get update -q
    sudo apt-get install -q -y -o Dpkg::Options::=--force-confnew mysql-server
    sudo mysql_upgrade -u root --force
    sudo service mysql restart
}

new_mysql_setup()
{
    MYSQL="mysql:8.0"
    sudo service mysql stop
    docker pull ${MYSQL}
    RUN_MYSQL="docker run -it --name=mysqld -d -e MYSQL_ALLOW_EMPTY_PASSWORD=yes -p 3306:3306"

    if [ $MYSQL == 'mysql:8.0' ]; then
        ${RUN_MYSQL} ${MYSQL} --default-authentication-plugin=mysql_native_password
    else
        ${RUN_MYSQL} ${MYSQL}
    fi

    while ! docker exec mysqld mysqladmin ping --host localhost --silent &> /dev/null ; do
        echo "Waiting for database connection..."
        sleep 2
    done
}

if [ "$DB" == 'mysql' ] || [ "$PAIR" == '1' ]; then
    new_mysql_setup
fi

bash ./scripts/setup.sh .ci/database.yml
make sam db:setup
