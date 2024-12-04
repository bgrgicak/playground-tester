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
#   get_log_files <item-type> -name "error.json"
get_log_files() {
    local item_type="$1"
    # Remove first parameter from $@ so we can pass all additional parameters to find
    shift
    find logs/$item_type/*/ -name "error.json" -mindepth 2 -maxdepth 2 -type f "$@"
}

# Get all errors of a given level from the JSON log file
#
# Usage:
#   get_errors_by_level <level> <log-file>
get_errors_by_level() {
    local level="$1"
    local log_file="$2"
    cat "$log_file" | jq '[.[] | select(.level == "'"$level"'")]'
}

# Get the number of errors of a given level from the JSON log file
#
# Usage:
#   get_number_of_errors_by_level <level> <log-file>
get_number_of_errors_by_level() {
    echo "$(get_errors_by_level "$1" "$2" | jq 'length')"
}
