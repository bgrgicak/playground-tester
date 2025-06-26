#!/bin/bash

# npx @php-watch/cli@1.1.2

# Loop through all php files in wordpress-develop/tests/phpunit/tests

cd wordpress-develop

# Initialize empty JSON array
echo '[]' > ../test-results.json

# TODO test all files in tests/phpunit/tests/**/*.php
for file in tests/phpunit/tests/*.php; do
    echo "Running $file" >&2

    # Capture output and exit code
    output=$(npx @php-wasm/cli@1.1.2 ./vendor/bin/phpunit $file 2>&1)
    exit_code=$?
    echo "Exit code: $exit_code" >&2

    if [ "$exit_code" -ne 0 ]; then
        echo -e "\033[0;31mTest failed: $file\033[0m" >&2

        # Run with regular PHP and capture output
        echo "Running with PHP: $file" >&2
        php_output=$(php ./vendor/bin/phpunit $file 2>&1)
        php_exit_code=$?

        # Add failed test result with PHP output using jq
        jq --arg test "$file" --arg error "$output" --arg php_output "$php_output" --argjson php_exit_code "$php_exit_code" \
           '. += [{"test": $test, "success": false, "error": $error, "php_output": $php_output, "php_exit_code": $php_exit_code}]' \
           ../test-results.json > ../test-results.tmp
        mv ../test-results.tmp ../test-results.json
    else
        echo -e "\033[0;32mTest passed: $file\033[0m" >&2
        # Add successful test result using jq
        jq --arg test "$file" '. += [{"test": $test, "success": true, "error": ""}]' ../test-results.json > ../test-results.tmp
        mv ../test-results.tmp ../test-results.json
    fi
done

cd ..