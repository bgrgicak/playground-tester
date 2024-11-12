#! /bin/bash
#
# Run tests for a single item
# The tester will run a single item through all tests located in the tests/ folder.
#
# Test results of all tests will be saved in a error.json file in the item's folder.
# The results of each test will be saved in a subfolder of the item's folder.
#
# Usage: ./scripts/run-tests.sh --plugins <path>
#
# Options:
#   --plugins <path>   Path to the plugins folder.
#   --themes <path>    Path to the themes folder.

test_type=""
item_path=""
item_type=""
wordpress_path=""
# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    -h|--help)
      grep '^#' "$0" | grep -v '#!/bin/bash' | sed 's/^#//' | tail -n +3
      exit 0
      ;;
    --plugins)
      item_path="$2"
      test_type="plugin"
      item_type="plugins"
      shift 2
      ;;
    --themes)
      item_path="$2"
      test_type="theme"
      item_type="themes"
      shift 2
      ;;
    --wordpress)
      wordpress_path="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

# Build base blueprint used for all tests
blueprint_path=$(./scripts/generate-blueprint.sh $item_path $item_type)

for test in $(ls tests/*.sh); do
    item_name=$(basename $item_path)
    test_name=$(basename $test .sh)
    log_folder="$item_path/$test_name"
    log_file="$log_folder/error.log"
    if [ ! -d "$log_folder" ]; then
        mkdir -p "$log_folder"
    fi
    echo "" > "$log_file"

    # Each test gets its own copy of WordPress.
    # This ensures each test starts with a clean WordPress installation.
    temp_folder=$(mktemp -d)
    cp -r "$wordpress_path" "$temp_folder/wordpress"

    result=$(./$test --blueprint $blueprint_path --wordpress $temp_folder/wordpress)
    # if result is empty, add empty log file
    # We use empty log file to indicate that the test passed
    if [ -z "$result" ]; then
        echo -e "\033[32m✓\033[0m $item_name passed $test_name"
        echo "" > "$log_file"
        # Add empty error.json file to indicate that the test passed
        echo "[]" > "$log_folder/error.json"
    else
        echo -e "\033[31m✗\033[0m $item_name failed $test_name"
        echo "$result" > "$log_file"
        # parse results
        ./scripts/parse-raw-logs.sh --test-name $test_name --item-type "$test_type" --item-name "$item_name" --input $log_file --output "$log_folder/error.json"
    fi

    rm -rf "$temp_folder"
done

# get all error.json files and merge them into a single file
jq -s 'flatten' $item_path/**/error.json > $item_path/error.json

failed_tests=$(cat "$item_path/error.json" | jq 'length')
exit $failed_tests
