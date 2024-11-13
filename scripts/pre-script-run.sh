#! /bin/bash
#
# This script is used to set up the environment for running scripts.
# It shouldn't be used directly, but rather sourced by other scripts.
#
# The following variables are set if they are not already set:
# PLAYGROUND_TESTER_PATH - Path to the Playground Tester root folder.
# PLAYGROUND_CLI_PATH - Path to the Playground CLI.
# PLAYGROUND_TESTER_NVM_DIR - Path to the NVM directory.
# PLAYGROUND_TESTER_DISABLE_GIT - Set to true to disable git commits. (false by default)
#
# The script also sources the NVM configuration and adds support for the --help flag.

if [ -z "$PLAYGROUND_TESTER_PATH" ]; then
    PLAYGROUND_TESTER_PATH=$(cd "$(dirname "$0")/.." && pwd)
fi
if [ -z "$PLAYGROUND_CLI_PATH" ]; then
    PLAYGROUND_CLI_PATH="$PLAYGROUND_TESTER_PATH/node_modules/@wp-playground/cli/cli.js"
fi
if [ -z "$PLAYGROUND_TESTER_NVM_DIR" ]; then
    PLAYGROUND_TESTER_NVM_DIR="$PLAYGROUND_TESTER_PATH/.nvm"
fi

# Set to true to disable git commits.
# Useful for development and testing.
if [ -z "$PLAYGROUND_TESTER_DISABLE_GIT" ]; then
    PLAYGROUND_TESTER_DISABLE_GIT=false
fi

source "$PLAYGROUND_TESTER_NVM_DIR/nvm.sh"

# This is checking for -h or --help flag
case "$1" in
    -h|--help)
        echo '';
        sed '/^[^#]/q' "$0" | \
        grep '^#' | \
        grep -v '#!/bin/bash' | \
        sed 's/^#//' | \
        sed 's/^ //' | \
        tail -n +3
        echo '';
        exit 0
        ;;
esac