#!/bin/bash
#
# Install dependencies required for the Playground Tester to run in a clean environment.
#
# The script will install dependencies for Playground Tester.
#
# Usage:
#   ./scripts/install-dependencies.sh
set -e

source "./scripts/pre-script-run.sh"

# Install dependencies
echo "Installing dependencies"
npm ci

# Build WordPress
echo "Building WordPress"
./scripts/build-wordpress.sh --output ./temp

# Install WordPress develop dependencies
echo "Installing WordPress develop dependencies"
cd ./wordpress-develop
composer install
npm install

cp wp-tests-config-sample.php wp-tests-config.php

# TODO configure MySQL
# TODO move unit test setup to a separate file

cd ..
