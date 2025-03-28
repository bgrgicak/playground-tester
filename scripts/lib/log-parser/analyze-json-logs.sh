#! /bin/bash
#
# Helper functions to analyze JSON logs and output a summary of the results.

source "./scripts/pre-script-run.sh"

# Get all log files for a given item type
# Pass additional parameters to filter the files
# All find parameters are supported
#
# Usage:
#   get_log_files <item-type> [--from-letter <letter>] [--to-letter <letter>] [<find-args>...]
get_log_files() {
    local item_type="$1"
    shift
    local from_letter="0"
    local to_letter="z"

    # Parse named arguments
    while [[ "$#" -gt 0 ]]; do
        case $1 in
            --from-letter)
                from_letter="$2"
                shift 2
                ;;
            --to-letter)
                to_letter="$2" 
                shift 2
                ;;
            *)
                break
                ;;
        esac
    done

    # Set default range if not specified
    from_letter="${from_letter:-0}"
    to_letter="${to_letter:-z}"

    # Generate a list of paths to search in based on the from and to letters
    local chars=(0 1 2 3 4 5 6 7 8 9 a b c d e f g h i j k l m n o p q r s t u v w x y z)
    local paths=()
    for letter in "${chars[@]}"; do
        if [[ "$letter" > "$from_letter" || "$letter" = "$from_letter" ]] && [[ "$letter" < "$to_letter" || "$letter" = "$to_letter" ]]; then
            paths+=("$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/$letter")
        fi
    done

    find "${paths[@]}" -mindepth 2 -maxdepth 2 -type f "$@"
}

# Get log files with errors
# Pass additional parameters to filter the files
# All find parameters are supported
#
# Usage:
#   get_log_files_with_errors <item-type> <limit>
get_log_files_with_errors() {
    local item_type="$1"
    local limit="$2"
    if [ -z "$limit" ]; then
        shift
        get_log_files "$item_type" -name "error.json" -size +3c "$@"
    else
        shift 2
        get_log_files "$item_type" -name "error.json" -size +3c "$@" | head -n "$limit"
    fi
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
#   get_first_n_logs_to_test <item-type> <batch-size> <from-letter> <to-letter>
get_first_n_logs_to_test() {
    local item_type="$1"
    local batch_size="$2"
    local from_letter="${3:-0}"
    local to_letter="${4:-z}"

    local all_log_files=$(get_log_files "$item_type" --from-letter "$from_letter" --to-letter "$to_letter" -name "*last-tested.txt"|
        awk -F'/' '{print $NF " " substr($0, 1, length($0)-length($NF)-1)}' |
        sort |
        cut -d' ' -f2-)
    echo "$all_log_files" |
        head -n "$batch_size"
}
