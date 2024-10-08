#! /bin/bash

# Create a reports folder if it doesn't exist
if [ ! -d "reports" ]; then
    mkdir reports
fi

function update_stats() {
    # Date
    date=$(date +"%Y-%m-%d")

    # Get the number of SQL errors
    sql_errors=$(jq -r '.[] | select(.type == "SQL") | .type' logs/error-log.json | wc -l)

    # Get the number of PHP errors
    php_errors=$(jq -r '.[] | select(.type == "PHP") | .type' logs/error-log.json | wc -l)

    # If a file has more then 1 character it means the plugin failed
    failed_plugins=$(find logs/ -type f -size +1c | wc -l)

    # Each tested plugin has a file in the logs folder
    tested_plugins=$(find logs/ -type f | wc -l)

    # Calculate the error rate
    error_rate=$(echo "scale=2; $failed_plugins / $tested_plugins * 100" | bc)

    # Create or update the Markdown file
    report_file="reports/playground_stats.md"

    if [ ! -f "$report_file" ]; then
        echo "# Playground Error Report" > "$report_file"
        echo "This report shows the number of errors for each of the top 1000 WordPress.org plugins produces and how it changes over time." >> "$report_file"
        echo "## Stats" >> "$report_file"
        echo "| Date | Failed plugins | SQL Errors | PHP Errors | Error rate |" >> "$report_file"
        echo "|------|----------------|------------|------------|------------|" >> "$report_file"
    fi

    # Create the new line
    new_line="| $date | $failed_plugins | $sql_errors | $php_errors | $error_rate |"

    # Check if the line already exists in the file if not prepend it to the table
    if ! grep -qF "$new_line" "$report_file"; then
        # Read the entire file content into a variable
        file_content=$(<"$report_file")

        # Extract the header (including the line with dashes)
        header=$(echo "$file_content" | sed -n '1,/^|------|----------------|------------|------------|------------|/p')

        # Extract the content after the header
        body=$(echo "$file_content" | sed '1,/^|------|----------------|------------|------------|------------|/d')

        # Combine header, new line, and body
        updated_content="${header}\n${new_line}\n${body}"

        # Write the updated content back to the file
        echo -e "$updated_content" > "$report_file"
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