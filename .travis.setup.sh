set -exo pipefail

if [ "$DB" == 'postgres' ] || [ "$PAIR" == '1' ]; then
    echo "==================================="
    echo "Create database for postgres"
    echo "==================================="
    psql -c 'create database jennifer_test;' -U postgres
fi

if [ "$DB" == 'mysql' ] || [ "$PAIR" == '1' ]; then
    echo "==================================="
    echo "Install newer MySQL"
    echo "==================================="
    sudo apt-key adv --keyserver pgp.mit.edu --recv-keys A4A9406876FCBD3C456770C88C718D3B5072E1F5
    wget http://dev.mysql.com/get/mysql-apt-config_0.8.1-1_all.deb
    sudo dpkg -i mysql-apt-config_0.8.1-1_all.deb
    sudo apt-get update -q
    sudo apt-get install -q -y -o Dpkg::Options::=--force-confnew mysql-server
    sudo mysql_upgrade -u root --force
    sudo service mysql restart

    echo "==================================="
    echo "Create database for mysql"
    echo "==================================="
    crystal ./examples/run.cr -- db:create
fi

echo "==================================="
echo "Run migrations"
echo "==================================="
crystal ./examples/run.cr -- db:migrate