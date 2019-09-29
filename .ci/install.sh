#!/bin/bash

set -exo pipefail

sudo apt install dlocate
ld -v
# dlocate ld
sudo apt-get install --reinstall binutils linux-libc-dev:amd64 llvm
