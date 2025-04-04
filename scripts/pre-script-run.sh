#! /bin/bash
#
# This script is used to set up the environment for running scripts.
# It shouldn't be used directly, but rather sourced by other scripts.
#
# The following variables are set if they are not already set:
# PLAYGROUND_TESTER_PATH - Path to the Playground Tester root folder.
# PLAYGROUND_CLI_PATH - Path to the Playground CLI.
# PLAYGROUND_TESTER_DISABLE_GIT - Set to true to disable git commits. (false by default)
#
# The script also adds support for the --help flag.
set -e

if [ -z "$PLAYGROUND_TESTER_PATH" ]; then
    PLAYGROUND_TESTER_PATH=$(pwd)
fi
if [ -z "$PLAYGROUND_CLI_PATH" ]; then
    PLAYGROUND_CLI_PATH="$PLAYGROUND_TESTER_PATH/node_modules/@wp-playground/cli/cli.js"
fi
if [ -z "$PLAYGROUND_TESTER_DATA_PATH" ]; then
    PLAYGROUND_TESTER_DATA_PATH="$PLAYGROUND_TESTER_PATH/data"
fi
if [ -z "$PLAYGROUND_TESTER_TEMP_PATH" ]; then
    PLAYGROUND_TESTER_TEMP_PATH="$PLAYGROUND_TESTER_PATH/temp"
fi
if [ -z "$PLAYGROUND_TESTER_WORDPRESS_PATH" ]; then
    PLAYGROUND_TESTER_WORDPRESS_PATH="$PLAYGROUND_TESTER_TEMP_PATH/wordpress"
fi

# Set to true to disable git commits.
# Useful for development and testing.
if [ -z "$PLAYGROUND_TESTER_DISABLE_GIT" ]; then
    PLAYGROUND_TESTER_DISABLE_GIT=false
fi

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