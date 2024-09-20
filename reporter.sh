#! /bin/bash

# Create a reports folder if it doesn't exist
if [ ! -d "reports" ]; then
    mkdir reports
fi

function update_stats() {
    # Date
    date=$(date +"%Y-%m-%d")

    # Get the total number of failed plugins
    failed_plugins=$(jq -r '.[] | .plugin' logs/error-log.json | sort -u | wc -l)

    # Get the number of SQL errors
    sql_errors=$(jq -r '.[] | select(.type == "SQL") | .type' logs/error-log.json | wc -l)

    # Get the number of PHP errors
    php_errors=$(jq -r '.[] | select(.type == "PHP") | .type' logs/error-log.json | wc -l)

    # Create or update the Markdown file
    report_file="reports/playground_stats.md"

    if [ ! -f "$report_file" ]; then
        echo "# Playground Error Report" > "$report_file"
        echo "This report shows the number of errors for each of the top 1000 WordPress.org plugins produces and how it changes over time." >> "$report_file"
        echo "## Stats" >> "$report_file"
        echo "| Date | Failed | SQL Errors | PHP Errors |" >> "$report_file"
        echo "|------|--------|------------|------------|" >> "$report_file"
    fi

    # Create the new line
    new_line="| $date | $failed_plugins | $sql_errors | $php_errors |"

    # Check if the line already exists in the file
    if ! grep -qF "$new_line" "$report_file"; then
        echo "$new_line" >> "$report_file"
    fi
}


function generate_sql_error_reports() {
    # Generate the Markdown file
    report_file="reports/sql-errors.md"

    echo "# SQL Errors Report" > "$report_file"
    echo "## Stats" >> "$report_file"
    echo "| Message | Plugin | Level | Report link |" >> "$report_file"
    echo "|---------|--------|-------|-------------|" >> "$report_file"

    # Get all SQL errors from the JSON file, sort them, and keep only unique lines
    unique_errors=$(jq -r '.[] | select(.type == "SQL") | "| \(.message) | \(.plugin) | \(.level) | [View logs](../logs/\(.plugin)) |"' logs/error-log.json | sort -u)

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
    echo "| Message | Plugin | Level | Logs |" >> "$report_file"
    echo "|---------|--------|-------|-------------|" >> "$report_file"

    # Get all PHP errors from the JSON file, sort them, and keep only unique lines
    unique_errors=$(jq -r '.[] | select(.type == "PHP") | "| \(.message) | \(.plugin) | \(.level) | [View logs](../logs/\(.plugin)) |"' logs/error-log.json | sort -u)

    # Append only new unique lines to the report file
    while IFS= read -r line; do
        if ! grep -qF "$line" "$report_file"; then
            echo "$line" >> "$report_file"
        fi
    done <<< "$unique_errors"
}

update_stats
generate_sql_error_reports
generate_php_error_reports