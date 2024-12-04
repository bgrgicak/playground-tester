#!/bin/bash

## TODO: Replace real plugin and theme with test ones

# Source helper functions
source "$(dirname "$0")/common-test-functions.sh"

run_test "Test a successful theme run"\
    "./scripts/run-tests.sh --plugin logs/plugins/g/google-maps-effortless --wordpress ./temp/wordpress" \
    "✗ google-maps-effortless failed asyncify-boot
✗ google-maps-effortless failed jspi-boot"

run_test "Test a successful plugin run"\
    "./scripts/run-tests.sh --plugin ./logs/plugins/0/0gravatar --wordpress ./temp/wordpress" \
    "✓ 0gravatar passed asyncify-boot
✓ 0gravatar passed jspi-boot"

run_test "Test a failed plugin run"\
    "./scripts/run-tests.sh --plugin logs/plugins/g/google-maps-effortless --wordpress ./temp/wordpress" \
    "✗ google-maps-effortless failed asyncify-boot
✗ google-maps-effortless failed jspi-boot"