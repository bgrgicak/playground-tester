#!/bin/bash
set -e

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
    validate_output "A file with 2 fatal errors should return 2 fatal errors" \
        "2" \
        "$(get_number_of_errors_by_level "FATAL" $temp_file)"
    validate_output "A fatal PHP error should have the type PHP" \
        '"PHP"' \
        "$(get_errors_by_level "FATAL" $temp_file | jq '.[1].type')"
    validate_output "A PHP error prefixed with 'Error:' should be parsed as a PHP error" \
        "1" \
        "$(get_number_of_errors_by_level "DEPRECATED" $temp_file)"
}

playground_boot_error_test() {
    local temp_file=$(mktemp)
    parse_raw_logs --test-name playground-boot-error \
        --plugin \
        --item-name playground-boot-error \
        --input ./scripts/unit-tests/raw-log-test-data/playground-boot-error.log \
        --output $temp_file

    validate_output "A file with 1 fatal Playground error should return 1 error" \
        "1" \
        "$(get_number_of_errors_by_level "FATAL" $temp_file)"
    validate_output "A fatal Playground error should have the type PLAYGROUND" \
        '"PLAYGROUND"' \
        "$(get_errors_by_level "FATAL" $temp_file | jq '.[0].type')"
}

empty_log_file_test
php_fatal_test
playground_boot_error_test
