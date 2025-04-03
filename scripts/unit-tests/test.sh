#!/bin/bash
set -e

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$0")"

# Initialize counters for passed and failed tests
PASSED_TESTS=0
FAILED_TESTS=0

# Print header
echo "Running unit tests..."
echo "===================="
echo

# Find and execute all test files in the directory
for test_file in "$SCRIPT_DIR"/test-*.sh; do
    echo "🔍 $(basename "$test_file")"
    echo "----------------"

    # Execute the test file
    if bash "$test_file"; then
        PASSED_TESTS=$((PASSED_TESTS+1))
    else
        FAILED_TESTS=$((FAILED_TESTS+1))
    fi

    echo
done

# Print summary
echo "===================="
echo "Test Results:"
echo "✅ Files passed: $PASSED_TESTS"
if [ $FAILED_TESTS -gt 0 ]; then
    echo "❌ Files failed: $FAILED_TESTS"
fi
echo "Total files: $((PASSED_TESTS + FAILED_TESTS))"

# Exit with failure if any test file failed
[ $FAILED_TESTS -eq 0 ]