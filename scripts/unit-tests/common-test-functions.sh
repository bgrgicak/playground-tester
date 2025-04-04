#!/bin/bash
set -e

# Normalize the output of a test to remove color codes,
# carriage returns, and trailing whitespace.
#
# Usage:
# normalize_string "Input string"
normalize_string() {
    local input="$1"
    echo "$input" | \
        sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" | \
        tr -d '\r' | \
        sed 's/[[:space:]]*$//'
}

# Validate the output of a test
#
# Usage:
# validate_output "Test name" "Expected output" "Actual output"
validate_output() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    # Normalize both strings using the new function
    expected=$(normalize_string "$expected")
    actual=$(normalize_string "$actual")

    if [ "$expected" = "$actual" ]; then
        echo "✅ Test passed: $test_name"
        return 0
    else
        echo "❌ Test failed: $test_name"
        echo "Expected: $expected"
        echo "Actual  : $actual"
        return 1
    fi
}

# Run a test and validate the output
# If the script returns a non-zero exit code the test will fail.
# If you need to test for a specific exit code,
# run the script directly and use validate_output to check the exit code.
#
# Usage:
# run_test "Test name" "Path to the script to run" "Expected output"
run_test() {
    local test_name="$1"
    local script_path="$2"
    local expected_output="$3"

    local actual_output=$(. $script_path)

    if [ $? -ne 0 ]; then
        validate_output "$test_name" "Exit code should be 0" "Exit code was $?"
        return 1
    fi
    validate_output "$test_name" "$expected_output" "$actual_output"
}
