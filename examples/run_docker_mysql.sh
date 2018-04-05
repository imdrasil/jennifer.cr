#!/bin/bash
HTTP_PROXY=http://proxy:3128 HTTPS_PROXY=https://proxy:3128 sudo docker run \
  -e MYSQL_ALLOW_EMPTY_PASSWORD=yes \
  -it \
  -p 127.0.0.1:11009:3306 \
  mysql
