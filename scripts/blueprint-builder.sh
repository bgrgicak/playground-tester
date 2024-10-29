#! /bin/bash

item_path=$1
item_type=$2

blueprint_path="$item_path/blueprint.json"

if [ -f "$blueprint_path" ]; then
    rm "$blueprint_path"
fi

slug=$(basename $item_path)

plugin_info_path="wp-public-data/$item_type/$slug.json"
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
else
    # Create blueprint with required plugins
    requires_plugins=$(echo "$plugin_info" | jq -r '.requires_plugins // [] | join(", ")')
    plugins=()
    if [ -n "$requires_plugins" ]; then
        IFS=', ' read -r -a required_array <<< "$requires_plugins"
        plugins+=("${required_array[@]}")
    fi
    plugins+=("$slug")
    plugins_json=$(printf '%s\n' "${plugins[@]}" | jq -R . | jq -s .)
    echo "{ \"plugins\": $plugins_json }" > "$blueprint_path"
fi

echo "$blueprint_path"