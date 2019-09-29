#!/bin/bash

if [ "$INTEGRATION" == '1' ]
then
  # crystal spec spec/**/*_test.cr
  crystal spec spec/integration/sam_test.cr && crystal spec spec/integration/concurrency_test.cr -Dpreview_mt
elif [ "MT" == '1' ]
then
  crystal spec -Dpreview_mt
else
  ./bin/ameba && crystal spec
fi
