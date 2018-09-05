#!/bin/bash

if [ "$INTEGRATION" == '1' ]; then
  # crystal spec spec/**/*_test.cr
  crystal spec spec/integration/sam_test.cr & crystal spec spec/integration/concurrency_test.cr
else
  crystal spec
fi
