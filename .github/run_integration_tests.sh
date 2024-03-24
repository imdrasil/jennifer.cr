#!/bin/bash

set -exo pipefail

if [ "$DB" == "postgres" ]
then
  sudo apt-get install postgresql-client -y
fi

# === general tests ===

crystal spec spec/integration/sam_test.cr
  # TODO: fix tests
  # && crystal spec spec/integration/concurrency_test.cr -Dpreview_mt

# === micrate tests ===

cp ./.github/shard_micrate.yml ./shard.yml

shards

crystal spec spec/integration/micrate_test.cr
