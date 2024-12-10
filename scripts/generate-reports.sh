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
source ./scripts/lib/wp-data/list-items.sh
source ./scripts/lib/logs/error-reports.sh

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

function get_report_without_wp_version_errors() {
    jq '[.[] | select(.result_2023 | startswith("Error: Min WP version") | not) | select(.result_2024 | startswith("Error: Min WP version") | not)]' \
        data/stats/playground-2023-2024-error-comparison.json
}

function generate_test_comparison_report() {
    local item_type=$1
    local report_file="$PLAYGROUND_TESTER_DATA_PATH/reports/test-comparison.md"
    local report_without_wp_version_errors=$(mktemp)
    get_report_without_wp_version_errors > "$report_without_wp_version_errors"

    echo "# Test Comparison Report" > "$report_file"
    echo "This report compares the test results for Playground from December 2023 and December 2024." >> "$report_file"

    # Calculate error rates using the filtered data
    local total_2023=$(jq length "$report_without_wp_version_errors")
    local errors_2023=$(jq '[.[] | select(.result_2023 != "ok")] | length' "$report_without_wp_version_errors")
    local total_2024=$(jq length "$report_without_wp_version_errors")
    local errors_2024=$(jq '[.[] | select(.result_2024 != "ok")] | length' "$report_without_wp_version_errors")

    local error_rate_2023=$(echo "scale=2; ($errors_2023 / $total_2023) * 100" | bc)
    local error_rate_2024=$(echo "scale=2; ($errors_2024 / $total_2024) * 100" | bc)
    local improvement=$(echo "scale=2; (($error_rate_2023 - $error_rate_2024) / $error_rate_2023) * 100" | bc)

    echo "## Stats" >> "$report_file"
    echo "| Year | Error Rate |" >> "$report_file"
    echo "|------|------------|" >> "$report_file"
    echo "| 2023 | ${error_rate_2023}% |" >> "$report_file"
    echo "| 2024 | ${error_rate_2024}% |" >> "$report_file"
    echo "| Improvement | ${improvement}% |" >> "$report_file"

    echo "## Report" >> "$report_file"
    echo "" >> "$report_file"
    echo "| Test Item | 2023 Result | 2024 Result |" >> "$report_file"
    echo "|-----------|-------------|-------------|" >> "$report_file"

    jq -r '
    . as $data |
    map(select(.slug != null)) |  # Ensure slug is present
    map({
        title: .slug,
        result_2023: (.result_2023 | if . == "ok" then "✅" else "❌" end),
        result_2024: (.result_2024 | if . == "ok" then "✅" else "❌" end)
    }) |
    .[] |
    "| \(.title) | \(.result_2023) | \(.result_2024) |"
    ' "$report_without_wp_version_errors" >> "$report_file"

    # Optionally, remove the temporary file after use
    rm "$report_without_wp_version_errors"
}

function generate_temporary_error_report() {
    local report_without_wp_version_errors=$(mktemp)
    get_report_without_wp_version_errors > "$report_without_wp_version_errors"

    local report_file="$PLAYGROUND_TESTER_PATH/temp/temporary-error-report.md"
    jq -r '
    . as $data |
    map(select(.slug != null)) |  # Ensure slug is present
    map({
        slug: .slug,
        result_2023: .result_2023,
        result_2024: .result_2024
    }) |
    .[] |
    select(.result_2024 == "Test timeout of 300000ms exceeded.") |
    .slug
    ' "$report_without_wp_version_errors" > "$report_file"
}

# generate_temporary_error_report


# update_stats
# generate_sql_error_reports
# generate_php_error_reports
# generate_playground_error_reports
generate_test_comparison_report "plugins"
# push_reports
