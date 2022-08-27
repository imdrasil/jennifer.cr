#!/bin/bash

set -exo pipefail

if [ $DB == 'postgres' ]
then
  sudo apt-get install postgresql-client -y
fi

crystal spec spec/integration/sam_test.cr &&
  # TODO: fix concurrency tests
  # crystal spec spec/integration/concurrency_test.cr -Dpreview_mt &&
  crystal spec spec/integration/micrate_test.cr
