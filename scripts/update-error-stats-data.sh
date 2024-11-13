#! /bin/bash
#
# Update error stats from log data.
# This script will update the `data/error-stats.json` file with the current error stats.
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

source ./scripts/pre-script-run.sh

stats_dir="data"
stats_file="$stats_dir/error-stats.json"

add_error_stats_files_if_missing() {
    if [ ! -d "$stats_dir" ]; then
        echo "Creating stats directory..."
        mkdir "$stats_dir"
    fi

    if [ ! -f "$stats_file" ]; then
        echo "Adding error rate stats files if missing..."
        echo "{}" > "$stats_file"
    fi
}

get_log_files_count() {
    item_type="$1"
    # Remove first parameter from $@ so we can pass all additional parameters to find
    shift
    find logs/$item_type/*/ -name "error.json" -mindepth 2 -maxdepth 2 -type f "$@" | wc -l
}

update_error_stats() {
    echo "Updating error rate stats..."

    plugins_tested=$(get_log_files_count plugins)
    themes_tested=$(get_log_files_count themes)

    # Files without errors contain only [] and a newline.
    # We can check if the file has more than 3 characters to check if it has errors.
    plugins_with_errors=$(get_log_files_count plugins -size +3c)
    themes_with_errors=$(get_log_files_count themes -size +3c)

    # Create new entry using date as key, but keep full timestamp in value
    date_key=$(date -u +"%Y-%m-%d")
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    new_entry=$(jq -n \
        --arg date "$date_key" \
        --arg timestamp "$timestamp" \
        --arg plugins_tested "$plugins_tested" \
        --arg themes_tested "$themes_tested" \
        --arg plugins_with_errors "$plugins_with_errors" \
        --arg themes_with_errors "$themes_with_errors" \
        '{
            ($date): {
                timestamp: $timestamp,
                plugins_tested: ($plugins_tested|tonumber),
                themes_tested: ($themes_tested|tonumber),
                plugins_with_errors: ($plugins_with_errors|tonumber),
                themes_with_errors: ($themes_with_errors|tonumber),
            }
        }')

    # Create temp file in same directory as stats file
    temp_file="${stats_file}.tmp.$$"
    jq --argjson entry "$new_entry" '. * $entry' "$stats_file" > "$temp_file" && mv "$temp_file" "$stats_file"
}

add_error_stats_files_if_missing
update_error_stats
