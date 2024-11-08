#! /bin/bash

test_type=""
item_path=""
item_type=""

# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
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
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

# Build base blueprint used for all tests
blueprint_path=$(./scripts/blueprint-builder.sh $item_path $item_type)

for test in $(ls tests/*.sh); do
    test_name=$(basename $test .sh)
    log_folder="$item_path/$test_name"
    log_file="$log_folder/error.log"
    if [ ! -d "$log_folder" ]; then
        mkdir -p "$log_folder"
    fi
    echo "" > "$log_file"

    result=$(./$test --blueprint $blueprint_path)
    # if result is empty, add empty log file
    # We use empty log file to indicate that the test passed
    if [ -z "$result" ]; then
        echo -e "\033[32m✓\033[0m $test_name passed for $item_path"
        echo "" > "$log_file"
        # Add empty error.json file to indicate that the test passed
        echo "[]" > "$log_folder/error.json"
    else
        echo -e "\033[31m✗\033[0m $test_name failed for $item_path"
        echo "$result" > "$log_file"
        # parse results
        ./scripts/raw-log-parser.sh --name $test_name --input $log_file --output "$log_folder/error.json" --type "$test_type"
    fi
done

# get all error.json files and merge them into a single file
jq -s 'flatten' $item_path/**/error.json > $item_path/error.json

failed_tests=$(cat "$item_path/error.json" | jq 'length')
exit $failed_tests
