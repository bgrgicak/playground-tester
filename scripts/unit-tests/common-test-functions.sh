#!/bin/bash

normalize_string() {
    local input="$1"
    echo "$input" | \
        sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,2};?)?)?[mGK]//g" | \
        tr -d '\r' | \
        sed 's/[[:space:]]*$//'
}

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

run_test() {
    local test_name="$1"
    local script_path="$2"
    local expected_output="$3"

    local actual_output=$(. $script_path)
    validate_output "$test_name" "$expected_output" "$actual_output"
}
