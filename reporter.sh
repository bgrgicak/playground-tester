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

update_stats
