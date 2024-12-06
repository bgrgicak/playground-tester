#! /bin/bash

source "./scripts/pre-script-run.sh"
source "./scripts/lib/playground-tests/wp-now.sh"

wp_now_test --wp-now="./node_modules/@wp-now/dec-2023/cli.js" "$@"