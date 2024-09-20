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

function parse_logs_to_json() {
    # Generate output file name
    output_file="$log_folder_path/error-log.json"

    # Check if output file exists and remove its content if it does
    if [ -f "$output_file" ]; then
        echo -n > "$output_file"
    fi


    # Process files and create a temporary file
    temp_file=$(mktemp)

    echo "[" > "$temp_file"

    first_file=true

    # Use find to get all non-json files and process them with jq
    find "$log_folder_path" -type f ! -name "*.json" | while read -r file; do
        if [ "$first_file" = true ]; then
            first_file=false
        else
            # Don't add a comma if the last file didn't have any errors to avoid invalid JSON.
            last_char=$(tail -c 2 "$temp_file" | cut -c 1)
            if [ "$last_char" != "," ]; then
                echo "," >> "$temp_file"
            fi
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
                            message: "",
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
                            plugin: ($file | split("/")[-1]),
                            details: $line
                        }]
                    elif length > 0 then
                        .[:-1] + [(last | .details += (if .details == "" then "" else "\n" end) + $line)]
                    else
                        .
                    end
                )
            )
        } | .content | map(
            if .details != "" then
                .message = (
                    if (.type == "SQL") then
                        (.details | gsub("<[^>]*>"; "") | split("Error message was: ")[1] | split("\n\nBacktrace:")[0])
                    elif (.type == "PHP") then
                        (.details | sub("^\\[[^\\]]+\\]\\s*PHP [^:]+:\\s*"; "") | split("\n")[0])
                    else
                        .details
                    end
                )
            else
                .
            end
        )
        ' "$file" | jq -c '.[]' | while read -r object; do
            if [ "$first_entry" = false ]; then
                echo "," >> "$temp_file"
            elif [ "$first_entry" = true ]; then
                first_entry=false
            fi
            echo "$object" >> "$temp_file"
        done
    done

    # Remove the trailing comma from the last entry
    sed -i '' '$ s/,$//' "$temp_file"

    echo "]" >> "$temp_file"

    # Move the temporary file to the final output file
    mv "$temp_file" "$output_file"

    echo "JSON output has been saved to $output_file"
}

function parse_json_to_csv() {
    # Generate input and output file names
    input_file="$log_folder_path/error-log.json"
    output_file="$log_folder_path/error-log.csv"

    # Check if input file exists
    if [ ! -f "$input_file" ]; then
        echo "Error: JSON input file '$input_file' not found"
        return 1
    fi

    # Check if output file exists and remove its content if it does
    if [ -f "$output_file" ]; then
        echo -n > "$output_file"
    fi

    echo "plugin,message,level,type,details" > "$output_file"

    jq -r '
    .[] |
    [.plugin, .message, .level, .type, .details] |
    @csv
    ' "$input_file" >> "$output_file"

    echo "CSV output has been saved to $output_file"
}


parse_logs_to_json
parse_json_to_csv
