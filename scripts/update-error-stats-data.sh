#! /bin/bash
#
# Update error stats from log data.
# This script will update the `data/stats/error-stats.json` file with the current error stats.
#
# Each date will have the following stats:
# - timestamp: The timestamp of the last log file processed.
# - plugins_tested: The number of plugins tested.
# - themes_tested: The number of themes tested.
# - plugins_with_errors: The number of plugins with errors.
# - themes_with_errors: The number of themes with errors.
#
# If the script is run multiple times in a day, it will update the existing entry for the current date.
#
# Usage: ./scripts/update-error-stats.sh

source ./scripts/pre-script-run.sh
source ./scripts/lib/log-parser/analyze-json-logs.sh

playground_stats_dir="$PLAYGROUND_TESTER_DATA_PATH/stats"
playground_stats_file="$playground_stats_dir/error-stats.json"

add_error_stat_files_if_missing() {
    if [ ! -d "$playground_stats_dir" ]; then
        echo "Creating stats directory..."
        mkdir "$playground_stats_dir"
    fi

    if [ ! -f "$playground_stats_file" ]; then
        echo "Adding error rate stats files if missing..."
        echo "{}" > "$playground_stats_file"
    fi
}

update_error_stats() {
    echo "Updating error rate stats..."

    local plugins_tested=$(get_log_files plugins | wc -l)
    local themes_tested=$(get_log_files themes | wc -l)

    # Files without errors contain only [] and a newline.
    # We can check if the file has more than 3 characters to check if it has errors.
    local plugins_with_errors=$(get_log_files_with_errors plugins | wc -l)
    local themes_with_errors=$(get_log_files_with_errors themes | wc -l)

    # Create new entry using date as key, but keep full timestamp in value
    local date_key=$(date -u +"%Y-%m-%d")
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local new_entry=$(jq -n \
        --arg date "$date_key" \
        --arg timestamp "$timestamp" \
        --arg plugins_tested "$plugins_tested" \
        --arg themes_tested "$themes_tested" \
        --arg plugins_with_errors "$plugins_with_errors" \
        --arg themes_with_errors "$themes_with_errors" \
        '{
            ($date): {
                "timestamp": $timestamp,
                "plugins_tested": ($plugins_tested|tonumber),
                "themes_tested": ($themes_tested|tonumber),
                "plugins_with_errors": ($plugins_with_errors|tonumber),
                "themes_with_errors": ($themes_with_errors|tonumber),
            }
        }')

    # Create temp file in same directory as stats file
    local temp_file="${playground_stats_file}.tmp.$$"
    jq --argjson entry "$new_entry" '. * $entry' "$playground_stats_file" > "$temp_file" && mv "$temp_file" "$playground_stats_file"
}

function generate_comparison_stats() {
    jq  '
        # Define function to clean ANSI escape sequences and replace newlines
        def clean_error:
            gsub("\u001b\\[[0-9;]*[a-zA-Z]|\\x1b\\[[0-9;]*[a-zA-Z]"; "") |
            gsub("\\n"; " ");

        [
            .suites[0].specs |
            .[] |
            {
                title: .title,
                year: (.title | startswith("Playground from December 2023") | if . then "2023" else "2024" end),
                slug: (.title |
                    sub("Playground from December 2023 - "; "") |
                    sub("Playground from December 2024 - "; "") |
                    sub(" should load"; "")
                ),
                ok: .ok,
                error: (
                    if .tests[0].results[0].error.message then
                        .tests[0].results[0].error.message | clean_error
                    else
                        null
                    end
                )
            }
        ] |
        sort_by(.slug, .year) |
        . as $data |
        reduce range(0; length) as $i (
            {};
            .[$data[$i].slug] += [$data[$i]]
        ) |
        to_entries |
        map({
            title: .value[0].title,
            slug: .value[0].slug,
            result_2023: (.value | map(select(.year == "2023"))[0] | if .ok then "ok" else .error end),
            result_2024: (.value | map(select(.year == "2024"))[0] | if .ok then "ok" else .error end)
        })
        ' "$1"
}

function update_comparison_stats() {
    echo "Updating comparison stats..."
    local initial_stats=$(mktemp)
    generate_comparison_stats playwright-report/playwright-results-full-run.json > "$initial_stats"
    local new_stats=$(mktemp)
    generate_comparison_stats playwright-report/playwright-results-timeout-errors.json > "$new_stats"
    jq -s '
        .[0] as $initial |
        .[1] as $new |
        $initial |
        map(
            . as $item |
            $new |
            map(select(.slug == $item.slug)) |
            if length > 0 then
                $item + {result_2024: .[0].result_2024}
            else
                $item
            end
        )
    ' "$initial_stats" "$new_stats" \
        > data/stats/playground-2023-2024-error-comparison.json
}

update_comparison_stats

# add_error_stat_files_if_missing
# update_error_stats
# update_comparison_stats