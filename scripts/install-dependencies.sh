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
