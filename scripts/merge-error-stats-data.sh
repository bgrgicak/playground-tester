#! /bin/bash
#
# Merge error stats from new test results.
# This script will update the `playground-2024-2025-error-comparison.json` file with new test results
# while preserving existing data for plugins that aren't in the new test run.
#
# The script merges data from `playwright-report/playwright-results.json` into the existing comparison file,
# updating only the entries that appear in the new results.
#
# Usage: ./scripts/merge-error-stats-data.sh

source ./scripts/pre-script-run.sh

comparison_file="playground-2024-2025-error-comparison.json"
playwright_results="playwright-report/playwright-results.json"

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
                year: (.title | startswith("Playground from November 6th 2024") | if . then "2024" else "2025" end),
                slug: (.title |
                    sub("Playground from November 6th 2024 - "; "") |
                    sub("Playground from November 6th 2025 - "; "") |
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
            result_2024: (.value | map(select(.year == "2024"))[0] | if . then (if .ok then "ok" else .error end) else null end),
            result_2025: (.value | map(select(.year == "2025"))[0] | if . then (if .ok then "ok" else .error end) else null end)
        })
        ' "$1"
}

function merge_comparison_stats() {
    echo "Merging comparison stats..."

    # Check if comparison file exists
    if [ ! -f "$comparison_file" ]; then
        echo "Comparison file does not exist. Creating new file..."
        generate_comparison_stats "$playwright_results" > "$comparison_file"
        echo "Created new comparison file."
        return
    fi

    # Generate new stats from playwright results
    local new_stats=$(mktemp)
    generate_comparison_stats "$playwright_results" > "$new_stats"

    # Merge: Keep all existing entries, update with new data where slug matches
    local temp_file="${comparison_file}.tmp.$$"
    jq -s '
        .[0] as $existing |
        .[1] as $new |

        # Create lookup map of new stats by slug
        ($new | map({key: .slug, value: .}) | from_entries) as $new_map |

        # Update existing entries with new data where available
        ($existing | map(
            . as $item |
            if $new_map[.slug] then
                # Merge: keep title and slug from existing, update results from new
                {
                    title: .title,
                    slug: .slug,
                    result_2024: ($new_map[.slug].result_2024 // .result_2024),
                    result_2025: ($new_map[.slug].result_2025 // .result_2025)
                }
            else
                # Keep existing item as-is if not in new results
                .
            end
        )) as $updated_existing |

        # Find new entries that don'\''t exist in existing data
        ($new | map(select(.slug as $slug | $existing | map(.slug) | index($slug) == null))) as $new_only |

        # Combine updated existing with new entries and sort by slug
        ($updated_existing + $new_only) | sort_by(.slug)
    ' "$comparison_file" "$new_stats" > "$temp_file"

    # Replace original file with merged result
    mv "$temp_file" "$comparison_file"

    # Clean up temp file
    rm -f "$new_stats"

    echo "Comparison stats merged successfully."
}

merge_comparison_stats
