#!/bin/bash

EXAMPLE_PATH="${1:-./examples/database.yml.example}"

cp $EXAMPLE_PATH ./examples/database.yml
mkdir ./examples/models
