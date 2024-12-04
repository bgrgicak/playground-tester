#!/bin/bash

source "$(dirname "$0")/common-test-functions.sh"
source "./scripts/lib/log-parser/parse-raw-logs.sh"
source "./scripts/lib/log-parser/analyze-json-logs.sh"

empty_log_file_test() {
    local temp_file=$(mktemp)
    parse_raw_logs --test-name empty \
        --plugin \
        --item-name empty \
        --input ./scripts/unit-tests/raw-log-test-data/empty.log \
        --output "$temp_file"

    validate_output "Empty log file should return an empty string" \
        "" \
        "$(cat $temp_file)"
}

php_fatal_test() {
    local temp_file=$(mktemp)
    parse_raw_logs --test-name php-fatal \
        --plugin \
        --item-name php-fatal \
        --input ./scripts/unit-tests/raw-log-test-data/log-with-php-deprecated-and-fatal-also-js-error.log \
        --output $temp_file

    validate_output "A file with 3 errors should return 3 errors" \
        "3" \
        "$(cat $temp_file | jq 'length')"
    validate_output "A file with 1 fatal error should return 1 fatal error" \
        "1" \
        "$(get_number_of_fatal_errors $temp_file)"
    validate_output "A PHP error prefixed with 'Error:' should be parsed as a PHP error" \
        "1" \
        "$(get_errors_by_level "DEPRECATED" $temp_file | jq 'length')"
}

# Run the tests
empty_log_file_test
php_fatal_test