#!/bin/bash
#
# Install dependencies required for the Playground Tester to run in a clean environment.
#
# This script will install NVM, Node.js and npm.
# After that it will install the dependencies for the Playground Tester.
#
# Usage:
#   ./scripts/install-dependencies.sh
set -e

source "./scripts/pre-script-run.sh"

# Source NVM
echo "Setting up NVM"
. $HOME/.nvm/nvm.sh > /dev/null 2>&1

# Install Node
echo "Installing Node"
nvm install $(cat .nvmrc)

# Install dependencies
echo "Installing dependencies"
npm ci

# Build WordPress
echo "Building WordPress"
./scripts/build-wordpress.sh --output ./temp
