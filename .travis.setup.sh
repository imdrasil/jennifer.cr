set -exo pipefail

if [ "$DB" == 'mysql' ] || [ "$PAIR" == '1' ]; then
    # Install newer MySQL
    sudo apt-key adv --recv-key --keyserver keyserver.ubuntu.com A4A9406876FCBD3C456770C88C718D3B5072E1F5
    wget http://dev.mysql.com/get/mysql-apt-config_0.8.1-1_all.deb
    sudo dpkg -i mysql-apt-config_0.8.1-1_all.deb
    sudo apt-get update -q
    sudo apt-get install -q -y -o Dpkg::Options::=--force-confnew mysql-server
    sudo mysql_upgrade -u root --force
    sudo service mysql restart
fi

crystal ./examples/run.cr -- db:setup
