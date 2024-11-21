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

if [ ! -d "reports" ]; then
    mkdir reports
fi

function update_stats() {
    report_file="reports/playground_stats.md"

    # Create the full markdown file
    echo "# Playground Error Report" > "$report_file"
    echo "This report shows the number of errors for each of the top WordPress.org plugins and themes." >> "$report_file"
    echo "" >> "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Date | Plugins Tested | Themes Tested | Plugins with Errors | Themes with Errors |" >> "$report_file"
    echo "|------|----------------|---------------|-------------------|-------------------|" >> "$report_file"

    # Read from error-stats.json and sort by date in reverse order
    jq -r 'to_entries | sort_by(.key) | reverse | .[] |
    "| \(.key) | \(.value.plugins_tested) | \(.value.themes_tested) | \(.value.plugins_with_errors) | \(.value.themes_with_errors) |"' \
    "data/error-stats.json" >> "$report_file"
}

function generate_sql_error_reports() {
    # Generate the Markdown file
    report_file="reports/sql-errors.md"

    echo "# SQL Errors Report" > "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Message |  Type  | Level | Test | Logs |" >> "$report_file"
    echo "|---------|--------|-------|------|------|" >> "$report_file"

    # Get all SQL errors from the JSON file, sort them, and keep only unique lines
    unique_errors=$(jq -r '.[] | select(.type == "SQL") | "| \(.message) | \(if .plugin then "plugin" elif .theme then "theme" else "unknown" end) | \(.level) | \(.test) | [View logs](../\(.log)) |"' "logs/*/*/*/error.json" | sort -u)

    # Append only new unique lines to the report file
    while IFS= read -r line; do
        if ! grep -qF "$line" "$report_file"; then
            echo "$line" >> "$report_file"
        fi
    done <<< "$unique_errors"
}

function generate_php_error_reports() {
    # Generate the Markdown file
    report_file="reports/php-errors.md"

    echo "# PHP Errors Report" > "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Message |  Type  | Level | Test | Logs |" >> "$report_file"
    echo "|---------|--------|-------|------|------|" >> "$report_file"

    # Get all PHP errors from the JSON file, sort them, and keep only unique lines
    unique_errors=$(jq -r '.[] | select(.type == "PHP") | "| \(.message) | \(if .plugin then "plugin" elif .theme then "theme" else "unknown" end) | \(.level) | \(.test) | [View logs](../\(.log)) |"' "logs/*/*/*/error.json" | sort -u)

    # Append only new unique lines to the report file
    while IFS= read -r line; do
        if ! grep -qF "$line" "$report_file"; then
            echo "$line" >> "$report_file"
        fi
    done <<< "$unique_errors"
}

function push_reports() {
    "scripts/save-changes.sh" --add reports/ --message "Last updated at $(date +"%Y-%m-%d %H:%M:%S")" --push
}

update_stats
# generate_sql_error_reports
# generate_php_error_reports
# push_reports