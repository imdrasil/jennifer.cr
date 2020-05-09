#!/bin/bash

EXAMPLE_PATH="${1:-./scripts/database.yml.example}"

cp $EXAMPLE_PATH ./scripts/database.yml
mkdir ./scripts/models
