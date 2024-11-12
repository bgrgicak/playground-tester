#! /bin/bash
#
# Generate a blueprint for a given item.
# The blueprint will install the item and any required dependencies.
#
# Usage:
#   ./scripts/generate-blueprint.sh --item-path <path> --plugin|--theme
#
# --item-path <path> Path to the item.
# --plugin|--theme Type of the item. Either "plugin" or "theme".

source "./scripts/pre-script-run.sh"

item_path=""
item_type=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --plugin) item_type="plugins"; shift 1;;
        --theme) item_type="themes"; shift 1;;
        --item-path) item_path="$2"; shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

blueprint_path="$item_path/blueprint.json"

if [ -f "$blueprint_path" ]; then
    rm "$blueprint_path"
fi

slug=$(basename $item_path)

plugin_info_path="$PLAYGROUND_TESTER_PATH/wp-public-data/$item_type/$slug.json"
if [ ! -f "$plugin_info_path" ]; then
    echo "$item_type $slug not found in $plugin_info_path"
    exit 1
fi

# Read plugin data from wp-public-data
plugin_info=$(cat "$plugin_info_path")
blueprint_url=$(echo "$plugin_info" | jq -r '.blueprints[0].url // empty')

if [ -n "$blueprint_url" ]; then
    # Use existing blueprint if available
    curl -s -o "$blueprint_path" "$blueprint_url"
elif [ "$item_type" = "plugins" ]; then
    # Create blueprint with required plugins
    requires_plugins=$(echo "$plugin_info" | jq -r '.requires_plugins // [] | join(", ")')
    plugins=()
    if [ -n "$requires_plugins" ]; then
        IFS=', ' read -r -a required_array <<< "$requires_plugins"
        plugins+=("${required_array[@]}")
    fi
    plugins+=("$slug")

    # Create the blueprint structure using jq
    jq -n --arg plugins "$(printf '%s\n' "${plugins[@]}")" '
        {
            steps: (
                $plugins | split("\n") | map({
                    step: "installPlugin",
                    pluginData: {
                        resource: "wordpress.org/plugins",
                        slug: .
                    },
                    options: {
                        activate: true
                    }
                })
            )
        }
    ' > "$blueprint_path"
elif [ "$item_type" = "themes" ]; then
    # Create blueprint with required themes
    requires_themes=$(echo "$plugin_info" | jq -r '.requires_themes // [] | join(", ")')
    themes=()
    if [ -n "$requires_themes" ]; then
        IFS=', ' read -r -a required_array <<< "$requires_themes"
        themes+=("${required_array[@]}")
    fi
    themes+=("$slug")

    # Create the blueprint structure using jq
    jq -n --arg themes "$(printf '%s\n' "${themes[@]}")" '
        {
            steps: (
                $themes | split("\n") | map({
                    step: "installTheme",
                    themeData: {
                        resource: "wordpress.org/themes",
                        slug: .
                    },
                    options: {
                        activate: true
                    }
                })
            )
        }
    ' > "$blueprint_path"
fi

echo "$blueprint_path"