#! /bin/bash

source "./scripts/pre-script-run.sh"

get_error_json_path() {
    local item_type=$1
    local item=$2
    local test_name=$3 || ""
    local first_letter=$(echo "$item" | cut -c1 | tr '[:upper:]' '[:lower:]')
    echo "$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/$first_letter/$item/$test_name/error.json"
}

get_error_count() {
    local item_type=$1
    local item=$2
    local test_name=$3
    local error_json_path=$(get_error_json_path "$item_type" "$item" "$test_name")
    local error_count=$(cat "$error_json_path" | jq length)
    echo $error_count
}
