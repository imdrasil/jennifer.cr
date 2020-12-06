#!/bin/bash

if [ "$INTEGRATION" == '1' ]
then
  ./bin/ameba && crystal spec spec/integration/sam_test.cr && crystal spec spec/integration/concurrency_test.cr -Dpreview_mt
fi

if [ "MT" == '1' ]
then
  crystal spec -Dpreview_mt
else
  crystal spec
fi
