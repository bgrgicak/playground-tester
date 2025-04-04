#!/bin/bash
set -e

## TODO: Replace real plugin and theme with test ones

# Source helper functions
source "./scripts/pre-script-run.sh"
source "$PLAYGROUND_TESTER_PATH/scripts/unit-tests/common-test-functions.sh"

run_test "Test a successful theme run"\
    "./scripts/run-tests.sh --theme $PLAYGROUND_TESTER_DATA_PATH/logs/themes/1/100-bytes --wordpress ./temp/wordpress" \
    "✓ 100-bytes passed ast-sqlite-boot
✓ 100-bytes passed asyncify-boot
✓ 100-bytes passed jspi-boot"

run_test "Test a successful plugin run"\
    "./scripts/run-tests.sh --plugin $PLAYGROUND_TESTER_DATA_PATH/logs/plugins/0/0gravatar --wordpress ./temp/wordpress" \
    "✓ 0gravatar passed ast-sqlite-boot
✓ 0gravatar passed asyncify-boot
✓ 0gravatar passed jspi-boot"

run_test "Test a failed plugin run"\
    "./scripts/run-tests.sh --plugin $PLAYGROUND_TESTER_DATA_PATH/logs/plugins/g/gl-import-external-images --wordpress ./temp/wordpress" \
    "✗ gl-import-external-images failed ast-sqlite-boot
✗ gl-import-external-images failed asyncify-boot
✗ gl-import-external-images failed jspi-boot"
