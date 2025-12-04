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
    jq '[.[] | select(.result_2024 | startswith("Error: Min WP version") | not) | select(.result_2025 | startswith("Error: Min WP version") | not)]' \
        playground-2024-2025-error-comparison.json
}

function generate_test_comparison_report() {
    local item_type=$1
    local report_file="test-comparison.md"
    local report_without_wp_version_errors=$(mktemp)
    get_report_without_wp_version_errors > "$report_without_wp_version_errors"

    # List of plugins that fail in native WP
    local native_wp_failed_plugins=("seo-ultimate" "spiderblocker" "wp-jalali")

    echo "# Playground MySQL and PHP compatibility improvements between 2024 and 2025" > "$report_file"
    echo "This report compares Playground from December 2024 and December 2025 by analyzing how many of the top 1000 plugins from WordPress.org can be activated in Playground." >> "$report_file"
    echo "To determine if a plugin is compatible, we use End to End tests where we activate the plugin together it's dependencies and check if it was successfully activated in Playground." >> "$report_file"

    # Calculate error rates using the filtered data
    local total=$(jq length "$report_without_wp_version_errors")
    local errors_2024=$(jq '[.[] | select(.result_2024 != "ok")] | length' "$report_without_wp_version_errors")
    local errors_2025=$(jq '[.[] | select(.result_2025 != "ok")] | length' "$report_without_wp_version_errors")
    local success_2024=$((total - errors_2024))
    local success_2025=$((total - errors_2025))

    # Count how many failed tests also fail in native WP (hardcoded list)
    local failed_in_wp_count=${#native_wp_failed_plugins[@]}

    # Calculate error rates: (Failed - Failed in WP) / (Tested - Failed in WP)
    local testable=$((total - failed_in_wp_count))
    local actual_errors_2024=$((errors_2024 - failed_in_wp_count))
    local actual_errors_2025=$((errors_2025 - failed_in_wp_count))

    local error_rate_2024=$(echo "scale=6; ($actual_errors_2024 / $testable) * 100" | bc | xargs printf "%.2f")
    local error_rate_2025=$(echo "scale=6; ($actual_errors_2025 / $testable) * 100" | bc | xargs printf "%.2f")
    local improvement=$(echo "scale=6; (($error_rate_2024 - $error_rate_2025) / $error_rate_2024) * 100" | bc | xargs printf "%.2f")

    echo "## Stats" >> "$report_file"
    echo "| Year | Tested | Works in Playground | Failed in Playground | Failed in WP | Error Rate |" >> "$report_file"
    echo "|------|--------|---------------------|----------------------|--------------|------------|" >> "$report_file"
    echo "| 2024 | ${total} | ${success_2024} | ${errors_2024} | ${failed_in_wp_count} | ${error_rate_2024}% |" >> "$report_file"
    echo "| 2025 | ${total} | ${success_2025} | ${errors_2025} | ${failed_in_wp_count} | ${error_rate_2025}% |" >> "$report_file"
    echo "| Improvement | - | - | - | - | ${improvement}% |" >> "$report_file"

    echo "## Report" >> "$report_file"
    echo "" >> "$report_file"
    echo "| Test Item | 2024 Result | 2025 Result | Works in native WP |" >> "$report_file"
    echo "|-----------|-------------|-------------|---------------------|" >> "$report_file"

    # Convert bash array to jq-compatible JSON array
    local failed_plugins_json=$(printf '%s\n' "${native_wp_failed_plugins[@]}" | jq -R . | jq -s .)

    jq -r --argjson failed_plugins "$failed_plugins_json" '
    . as $data |
    map(select(.slug != null)) |  # Ensure slug is present
    map({
        slug: .slug,
        result_2024: (.result_2024 | if . == "ok" then "✅" else "❌" end),
        result_2025: (.result_2025 | if . == "ok" then "✅" else "❌" end),
        native_wp: (if (. as $item | $failed_plugins | map(. == $item.slug) | any) then "❌" else "✅" end)
    }) |
    .[] |
    "| \(.slug) | \(.result_2024) | \(.result_2025) | \(.native_wp) |"
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
        result_2024: .result_2024,
        result_2025: .result_2025
    }) |
    .[] |
    select(.result_2025 == "Test timeout of 300000ms exceeded.") |
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
