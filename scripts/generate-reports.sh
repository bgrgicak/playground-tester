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
source ./scripts/lib/log-parser/parse-raw-logs.sh
source ./scripts/save-data.sh

if [ ! -d "$PLAYGROUND_TESTER_DATA_PATH/reports" ]; then
    mkdir "$PLAYGROUND_TESTER_DATA_PATH/reports"
fi

function update_stats() {
    local report_file="$PLAYGROUND_TESTER_DATA_PATH/reports/playground-stats.md"

    # Create the full markdown file
    echo "# Playground Error Report" > "$report_file"
    echo "This report shows the number of errors for each of the top WordPress.org plugins and themes in the last 90 days." >> "$report_file"
    echo "" >> "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Date | Error rate (%) | Plugins Tested | Themes Tested | Plugins with Errors | Themes with Errors |" >> "$report_file"
    echo "|------|----------------|----------------|---------------|---------------------|--------------------|" >> "$report_file"

    # Read from error-stats.json and sort by date in reverse order
    # Only show the last 90 days of stats
    jq -r 'to_entries | sort_by(.key) | reverse | .[0:90] | .[] |
    "| \(.key) | \(((.value.plugins_with_errors + .value.themes_with_errors) / (.value.plugins_tested + .value.themes_tested) * 100000 | floor * 0.001 ))% | \(.value.plugins_tested) | \(.value.themes_tested) | \(.value.plugins_with_errors) | \(.value.themes_with_errors) |"' \
    "$PLAYGROUND_TESTER_DATA_PATH/stats/error-stats.json" >> "$report_file"
}

function generate_error_report() {
    local type=$1
    local log_files_with_errors=$2
    local name=$(echo "$type" | tr '[:upper:]' '[:lower:]')
    local report_file="$PLAYGROUND_TESTER_DATA_PATH/reports/${name}-errors.md"

    echo "# ${type} Errors Report" > "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Message | Test | Item | Logs |" >> "$report_file"
    echo "|---------|------|------|------|" >> "$report_file"

    while read -r file; do
        if [ -z "$(cat "$file")" ] || [ "$(jq length "$file")" -eq 0 ]; then
            continue
        fi
            local item_name=$(basename "$(dirname "$file")")
            local item_type=$(basename "$(dirname "$(dirname "$(dirname "$file")")")")
            local log_file_path=$(get_log_file_git_path "$item_type" "$item_name")
            jq -r --arg type "$type" --arg log_file_path "$log_file_path" --arg item_name "$item_name" \
                '.[] | select(.type == $type) | select(.level == "FATAL") | "| \(.message) | \(.test) | \($item_name) | [View logs](\($log_file_path)) |"' \
            "$file" | \
            sort -u >> "$report_file"
    done < "$log_files_with_errors"
}

function generate_ast_errors_report() {
    local log_files_with_errors=$1
    local report_file="$PLAYGROUND_TESTER_DATA_PATH/reports/ast-errors.md"

    echo "# AST Errors Report" > "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Item | Message | Logs |" >> "$report_file"
    echo "|------|---------|------|" >> "$report_file"
    while read -r file; do
        if [ -z "$(cat "$file")" ] || [ "$(jq length "$file")" -eq 0 ]; then
            continue
        fi
        local item_name=$(basename "$(dirname "$file")")
        local item_type=$(basename "$(dirname "$(dirname "$(dirname "$file")")")")
        local item_path=$(get_item_path "$item_type" "$item_name")
        local failed_tests=$(get_failed_tests_for_item "$item_path")
        local log_file_path=$(get_log_file_git_path "$item_type" "$item_name")
        if has_item_a_failed_test "$item_path" "ast-sqlite-boot" && ! has_item_a_failed_test "$item_path" "asyncify-boot"; then
            # Filter for ast-sqlite-boot tests and messages not starting with file:///
            jq -r '.[] | select(.test == "ast-sqlite-boot" and (.message | startswith("file:///") | not)) | .message' "$item_path/ast-sqlite-boot/error.json" | while read -r message; do
                echo "| $item_name | $message | [View logs]($log_file_path) |" >> "$report_file"
            done
        fi
    done < "$log_files_with_errors"
}

generate_error_reports() {
    local log_files_with_errors=$(mktemp)
    get_log_files_with_errors "plugins" >> "$log_files_with_errors"
    get_log_files_with_errors "themes" >> "$log_files_with_errors"

    generate_error_report "SQL" $log_files_with_errors
    generate_error_report "PHP" $log_files_with_errors
    generate_error_report "PLAYGROUND" $log_files_with_errors
    generate_ast_errors_report "$log_files_with_errors"
}

update_stats
generate_error_reports

