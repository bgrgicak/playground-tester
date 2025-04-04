#! /bin/bash
#
# Update error stats from log data.
# This script will update the `data/stats/error-stats.json` file with the current error stats.
#
# Each date will have the following stats:
# - timestamp: The timestamp of the last log file processed.
# - plugins_tested: The number of plugins tested.
# - themes_tested: The number of themes tested.
# - plugins_with_errors: The number of plugins with errors.
# - themes_with_errors: The number of themes with errors.
#
# If the script is run multiple times in a day, it will update the existing entry for the current date.
#
# Usage: ./scripts/update-error-stats.sh
set -e

source ./scripts/pre-script-run.sh
source ./scripts/lib/log-parser/analyze-json-logs.sh
source ./scripts/save-data.sh

playground_stats_dir="$PLAYGROUND_TESTER_DATA_PATH/stats"
playground_stats_file="$playground_stats_dir/error-stats.json"

add_error_stat_files_if_missing() {
    if [ ! -d "$playground_stats_dir" ]; then
        echo "Creating stats directory..."
        mkdir "$playground_stats_dir"
    fi

    if [ ! -f "$playground_stats_file" ]; then
        echo "Adding error rate stats files if missing..."
        echo "{}" > "$playground_stats_file"
    fi
}

update_error_stats() {
    echo "Updating error rate stats..."

    local plugins_tested=$(get_log_files plugins -name "error.json" | wc -l)
    local themes_tested=$(get_log_files themes -name "error.json" | wc -l)

    # Files without errors contain only [] and a newline.
    # We can check if the file has more than 3 characters to check if it has errors.
    local plugins_with_errors=$(get_log_files_with_errors plugins | wc -l)
    local themes_with_errors=$(get_log_files_with_errors themes | wc -l)

    # Create new entry using date as key, but keep full timestamp in value
    local date_key=$(date -u +"%Y-%m-%d")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local new_entry=$(jq -n \
        --arg date "$date_key" \
        --arg timestamp "$timestamp" \
        --arg plugins_tested "$plugins_tested" \
        --arg themes_tested "$themes_tested" \
        --arg plugins_with_errors "$plugins_with_errors" \
        --arg themes_with_errors "$themes_with_errors" \
        '{
            ($date): {
                "timestamp": $timestamp,
                "plugins_tested": ($plugins_tested|tonumber),
                "themes_tested": ($themes_tested|tonumber),
                "plugins_with_errors": ($plugins_with_errors|tonumber),
                "themes_with_errors": ($themes_with_errors|tonumber),
            }
        }')

    # Create temp file in same directory as stats file
    local temp_file="${playground_stats_file}.tmp.$$"
    jq --argjson entry "$new_entry" '. * $entry' "$playground_stats_file" > "$temp_file" && mv "$temp_file" "$playground_stats_file"
}

add_error_stat_files_if_missing
update_error_stats