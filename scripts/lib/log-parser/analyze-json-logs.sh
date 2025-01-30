#! /bin/bash
#
# Helper functions to analyze JSON logs and output a summary of the results.

source "./scripts/pre-script-run.sh"

# Get all log files for a given item type
# Pass additional parameters to filter the files
# All find parameters are supported
#
# Usage:
#   get_log_files <item-type>
#   get_log_files <item-type> "error.json"
get_log_files() {
    local item_type="$1"
    # Remove first parameter from $@ so we can pass all additional parameters to find
    shift
    find "$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/" -mindepth 3 -maxdepth 3 -type f "$@"
}

# Get log files with errors
# Pass additional parameters to filter the files
# All find parameters are supported
#
# Usage:
#   get_log_files_with_errors <item-type>
get_log_files_with_errors() {
    local item_type="$1"
    shift
    get_log_files "$item_type" -name "error.json" -size +3c "$@"
}

# Get all errors of a given level from the JSON log file
#
# Usage:
#   get_errors_by_level <level> <log-file>
get_errors_by_level() {
    local level="$1"
    local log_file="$2"
    jq '[.[] | select(.level == "'"$level"'")]' "$log_file"
}

# Get the number of errors of a given level from the JSON log file
#
# Usage:
#   get_number_of_errors_by_level <level> <log-file>
get_number_of_errors_by_level() {
    echo "$(get_errors_by_level "$1" "$2" | jq 'length')"
}

# Get the first n logs to test.
# We first need to test logs that have not been
# tested for the longest time.
# The last tested time is stored in TIMESTAMP-last-tested.txt
# file located in log directories of each item.
#
# Usage:
#   get_first_n_logs_to_test <item-type> <batch-size>
get_first_n_logs_to_test() {
    local item_type="$1"
    local batch_size="$2"

    local all_log_files=$(get_log_files "$item_type" -name "*last-tested.txt"|
        awk -F'/' '{print $NF " " substr($0, 1, length($0)-length($NF)-1)}' |
        sort |
        cut -d' ' -f2-)
    echo "$all_log_files" |
        head -n "$batch_size"
}

