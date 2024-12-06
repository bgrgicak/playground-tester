#! /bin/bash
#
# Parse raw logs from the Playground Tester and save them to a JSON file.
#
# Usage:
#   parse_raw_logs --test-name <test-name> --plugin|--theme --item-name <item-name> --input <input> --output <output>
#
# --test-name <test-name> Name of the test that was run. It must be a valid .sh file name inside the tests/ folder.
# --plugin|--theme Type of the item that was tested.
# --item-name <item-name> Name of the item that was tested.
# --input <input> Path to the raw logs file.
# --output <output> Path to the output JSON file.

source "./scripts/pre-script-run.sh"

prepare_log_file() {
    local input="$1"
    local temp_file=$(mktemp)
    cat $input > $temp_file

    # Remove the line that starts with "Node.js v"
    # This is output by the Playground CLI when it runs the tests
    sed -i.bak '/^Node.js v/d' $temp_file

    # If there is a "Error: " string before the start of a PHP error,
    # remove the "Error: " string
    sed -i.bak '/^Error: \[[0-9][0-9]-[A-Za-z][A-Za-z][A-Za-z]-[0-9][0-9][0-9][0-9] [0-9][0-9]:[0-9][0-9]:[0-9][0-9] UTC\]/s/^Error: //' $temp_file

    # Remove backup files created by sed
    rm "${temp_file}.bak"

    cat $temp_file
}

parse_raw_logs() {
    local test_name=""
    local item_type=""
    local item_name=""
    local input=""
    local output=""
    # Parse command line options
    while [[ "$#" -gt 0 ]]; do
    case $1 in
        --test-name)
        test_name="$2"
        shift 2
        ;;
        --plugin)
        item_type="plugins"
        shift 1
        ;;
        --theme)
        item_type="themes"
        shift 1
        ;;
        --item-name)
        item_name="$2"
        shift 2
        ;;
        --input)
        input="$2"
        shift 2
        ;;
        --output)
        output="$2"
        shift 2
        ;;
        *)
        echo "Invalid option: $1" >&2
        exit 1
        ;;
        esac
    done

    local parsed_input_file=$(mktemp)
    prepare_log_file "$input" > "$parsed_input_file"

    # Check if file is empty or contains only whitespace
    if [ ! -s "$parsed_input_file" ] || ! grep -q '[^[:space:]]' "$parsed_input_file"; then
        return  # Skip empty files or files with only whitespace
    fi

    # Process files and create a temporary file
    local temp_file=$(mktemp)

    echo "[" > "$temp_file"
    local first_entry=true
    jq -Rs --arg input "$parsed_input_file" --arg test_name "$test_name" --arg item_type "$item_type" --arg item_name "$item_name" '
    {
        "filename": $input,
        "plugin": ($input | split("/")[-1]),
        "content": (
            split("\n") |
            reduce .[] as $line (
                [];
                if ($line | test("^\\[[0-9]{2}-[A-Za-z]{3}-[0-9]{4} [0-9]{2}:[0-9]{2}:[0-9]{2} UTC\\]")) then
                    . + [{
                        "message": "",
                        "level": (
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
                        "type": (
                            if ($line | test("^\\[[^\\]]+\\]\\s*WordPress database")) then
                                "SQL"
                            elif ($line | test("^\\[[^\\]]+\\]\\s*PHP")) then
                                "PHP"
                            else
                                "OTHER"
                            end
                        ),
                        "test": $test_name,
                        ($item_type): $item_name,
                        "details": $line,
                        "log": $input
                    }]
                elif ($line | test("^file:///.*\\.js:[0-9]+")) then
                    . + [{
                        "message": "",
                        "level": "FATAL",
                        "type": "PLAYGROUND",
                        "test": $test_name,
                        ($item_type): $item_name,
                        "details": $line,
                        "log": $input
                    }]
                elif ($line | test("^npm error")) then
                    . + [{
                        "message": "",
                        "level": "FATAL",
                        "type": "PLAYGROUND",
                        "test": $test_name,
                        ($item_type): $item_name,
                        "details": $line,
                        "log": $input
                    }]
                elif ($line | test("^Error when executing the blueprint step")) then
                    . + [{
                        "message": "",
                        "level": "FATAL",
                        "type": "PLAYGROUND",
                        "test": $test_name,
                        ($item_type): $item_name,
                        "details": $line,
                        "log": $input
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
                    (.details | gsub("<[^>]*>"; "") | split("Error message was: ")[1] // empty | split("\n\nBacktrace:")[0])
                elif (.type == "PHP") then
                    (.details | sub("^\\[[^\\]]+\\]\\s*PHP [^:]+:\\s*"; "") | split("\n")[0])
                elif (.type == "PLAYGROUND") then
                    .details
                else
                    .details
                end
            )
        else
            .
        end
    )
    ' "$parsed_input_file" | jq -c '.[]' | while read -r object; do
        if [ "$first_entry" = false ]; then
            echo "," >> "$temp_file"
        elif [ "$first_entry" = true ]; then
            first_entry=false
        fi
        echo "$object" >> "$temp_file"
    done

    echo "]" >> "$temp_file"


    # Check if output file exists and remove its content if it does
    if [ -f "$output" ]; then
        echo -n > "$output"
    fi
    # Move the temporary file to the final output file
    mv "$temp_file" "$output"
}