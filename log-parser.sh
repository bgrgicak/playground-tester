#!/bin/bash

# Check if a folder path is provided as an argument
if [ $# -eq 0 ]; then
    echo "Usage: $0 <log_folder_path>"
    exit 1
fi

log_folder_path="$1"

# Check if the provided path is a directory
if [ ! -d "$log_folder_path" ]; then
    echo "Error: '$log_folder_path' is not a valid directory"
    exit 1
fi

# Generate output file name
output_file="$log_folder_path/error-log.json"

# Process files and create a temporary file
temp_file=$(mktemp)

echo "[" > "$temp_file"

first_file=true

# Use find to get all non-json files and process them with jq
find "$log_folder_path" -type f ! -name "*.json" | while read -r file; do
    if [ "$first_file" = false ]; then
        echo "," >> "$temp_file"
    elif [ "$first_file" = true ]; then
        first_file=false
    fi

    first_entry=true
    jq -Rs --arg file "$file" '
    {
        filename: $file,
        plugin: ($file | split("/")[-1]),
        content: (
            split("\n") |
            reduce .[] as $line (
                [];
                if ($line | test("^\\[[0-9]{2}-[A-Za-z]{3}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC\\]")) then
                    . + [{
                        timestamp: ($line | capture("^\\[(?<ts>[^\\]]+)\\]") | .ts),
                        message: ($line | sub("^\\[[^\\]]+\\]\\s*"; "")),
                        level: (
                            if ($line | test("^\\[[^\\]]+\\]\\s*PHP Fatal error")) then
                                "FATAL"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP Warning")) then
                                "WARNING"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP Parse error")) then
                                "PARSE"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP Notice")) then
                                "NOTICE"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP Deprecated")) then
                                "DEPRECATED"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP Strict Standards")) then
                                "STRICT"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP Recoverable fatal error")) then
                                "RECOVERABLE_FATAL"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*WordPress database")) then
                                "FATAL"
                            else
                                "INFO"
                            end
                        ),
                        type: (
                            if ($line | test("^\\[[^\\]]+\\]\\s*WordPress database")) then
                                "SQL"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP")) then
                                "PHP"
                            else
                                "OTHER"
                            end
                        ),
                        details: ""
                    }]
                elif length > 0 then
                    .[:-1] + [(last | .details += (if .details == "" then "" else "\n" end) + $line)]
                else
                    .
                end
            )
        )
    } | .content
    ' "$file" | jq -c '.[]' | while read -r object; do
        if [ "$first_entry" = false ]; then
            echo "," >> "$temp_file"
        elif [ "$first_entry" = true ]; then
            first_entry=false
        fi
        echo "$object" >> "$temp_file"
    done
done

echo "]" >> "$temp_file"

# Move the temporary file to the final output file
mv "$temp_file" "$output_file"

echo "JSON output has been saved to $output_file"