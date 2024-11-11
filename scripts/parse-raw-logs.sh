#! /bin/bash

name=""
input=""
output=""
type=""
# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --name)
      name="$2"
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
    --type)
      type="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

# Check if file is empty or contains only whitespace
if [ ! -s "$input" ] || ! grep -q '[^[:space:]]' "$input"; then
    exit 0  # Skip empty files or files with only whitespace
fi

# Process files and create a temporary file
temp_file=$(mktemp)

echo "[" > "$temp_file"

first_entry=true
jq -Rs --arg input "$input" --arg name "$name" --arg type "$type" '
{
    filename: $input,
    plugin: ($input | split("/")[-1]),
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
                    test: $name,
                    $type: ($input | split("/")[-2]),
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
                (.details | gsub("<[^>]*>"; "") | split("Error message was: ")[1] // empty | split("\n\nBacktrace:")[0])
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
' "$input" | jq -c '.[]' | while read -r object; do
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
