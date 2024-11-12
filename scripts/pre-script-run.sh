#! /bin/bash
#
# This script is used to set up the environment for running scripts.
#

PLAYGROUND_TESTER_PATH=$(cd "$(dirname "$0")/.." && pwd)
PLAYGROUND_CLI_PATH="$PLAYGROUND_TESTER_PATH/node_modules/@wp-playground/cli/cli.js"
PLAYGROUND_TESTER_NVM_DIR="$PLAYGROUND_TESTER_PATH/.nvm"

# Disable git commits
# Useful for development
# @TODO: Remove this before release
export PLAYGROUND_TESTER_DISABLE_GIT=true

source "$PLAYGROUND_TESTER_NVM_DIR/nvm.sh"

# This is checking for -h or --help flag
case "$1" in
    -h|--help)
        grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^#//' | tail -n +3
        exit 0
        ;;
esac