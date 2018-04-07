#!/bin/bash

if [ "$INTEGRATION" == '1' ]; then
  crystal spec spec/**/*_test.cr
else
  crystal spec
fi
