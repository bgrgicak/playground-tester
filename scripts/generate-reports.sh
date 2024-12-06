#! /bin/bash
#
# Generate reports from logs.
# The script will create or update the reports/ folder with the latest reports.
#
# - playground_stats.md - Error rate over time.
# - sql-errors.md - All unique SQL errors with links to the logs.
# - php-errors.md - All unique PHP errors with links to the logs.
#
# Usage:
#   ./scripts/generate-reports.sh

source "./scripts/pre-script-run.sh"
source ./scripts/lib/log-parser/analyze-json-logs.sh
source ./scripts/save-data.sh

if [ ! -d "$PLAYGROUND_TESTER_DATA_PATH/reports" ]; then
    mkdir "$PLAYGROUND_TESTER_DATA_PATH/reports"
fi

function update_stats() {
    local report_file="$PLAYGROUND_TESTER_DATA_PATH/reports/playground_stats.md"

    # Create the full markdown file
    echo "# Playground Error Report" > "$report_file"
    echo "This report shows the number of errors for each of the top WordPress.org plugins and themes in the last 90 days." >> "$report_file"
    echo "" >> "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Date | Plugins Tested | Themes Tested | Plugins with Errors | Themes with Errors |" >> "$report_file"
    echo "|------|----------------|---------------|-------------------|-------------------|" >> "$report_file"

    # Read from error-stats.json and sort by date in reverse order
    # Only show the last 90 days of stats
    jq -r 'to_entries | sort_by(.key) | reverse | .[0:90] | .[] |
    "| \(.key) | \(.value.plugins_tested) | \(.value.themes_tested) | \(.value.plugins_with_errors) | \(.value.themes_with_errors) |"' \
    "$PLAYGROUND_TESTER_DATA_PATH/stats/error-stats.json" >> "$report_file"
}

function generate_error_reports() {
    local type=$1
    local name=$(echo "$type" | tr '[:upper:]' '[:lower:]')
    local report_file="$PLAYGROUND_TESTER_DATA_PATH/reports/${name}-errors.md"

    echo "# ${type} Errors Report" > "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Message | Test | Logs |" >> "$report_file"
    echo "|---------|------|------|" >> "$report_file"

    # for themes and plugins
    for item_type in "plugins" "themes"; do
        get_log_files_with_errors "$item_type" | while read -r file; do
            if [ -z "$(cat "$file")" ] || [ "$(jq length "$file")" -eq 0 ]; then
                continue
            fi
            jq -r --arg type "$type" \
                '.[] | select(.type == $type) | select(.level == "FATAL") | "| \(.message) | \(.test) | [View logs](../\(.log)) |"' \
                "$file" | \
                sort -u >> "$report_file"
        done
    done
}

function generate_sql_error_reports() {
    generate_error_reports "SQL"
}

function generate_php_error_reports() {
    generate_error_reports "PHP"
}

function generate_playground_error_reports() {
    generate_error_reports "PLAYGROUND"
}


function push_reports() {
    save_data --add reports/ --message "Last updated at $(date +"%Y-%m-%d %H:%M:%S")" --push
}

update_stats
generate_sql_error_reports
generate_php_error_reports
generate_playground_error_reports
push_reports
