#!/bin/bash

## TODO: Replace real plugin and theme with test ones

# Source helper functions
source "./scripts/pre-script-run.sh"
source "$PLAYGROUND_TESTER_PATH/scripts/unit-tests/common-test-functions.sh"

run_test "Test a successful theme run"\
    "./scripts/run-tests.sh --theme $PLAYGROUND_TESTER_DATA_PATH/logs/themes/1/100-bytes --wordpress ./temp/wordpress" \
    "✓ 100-bytes passed asyncify-boot
✓ 100-bytes passed jspi-boot
✓ 100-bytes passed wp-now-dec-2023
✓ 100-bytes passed wp-now"

run_test "Test a successful plugin run"\
    "./scripts/run-tests.sh --plugin $PLAYGROUND_TESTER_DATA_PATH/logs/plugins/0/0gravatar --wordpress ./temp/wordpress" \
    "✓ 0gravatar passed asyncify-boot
✓ 0gravatar passed jspi-boot
✓ 0gravatar passed wp-now-dec-2023
✓ 0gravatar passed wp-now"

run_test "Test a failed plugin run"\
    "./scripts/run-tests.sh --plugin $PLAYGROUND_TESTER_DATA_PATH/logs/plugins/g/google-maps-effortless --wordpress ./temp/wordpress" \
    "✗ google-maps-effortless failed asyncify-boot
✗ google-maps-effortless failed jspi-boot
✗ google-maps-effortless failed wp-now-dec-2023
✗ google-maps-effortless failed wp-now"
