#! /bin/bash
#
# Generate a blueprint for a given item.
# The blueprint will install the item and any required dependencies.
#
# Usage:
#   ./scripts/lib/blueprints/generate-blueprint.sh --item-path <path> --plugin|--theme
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

item_info_path="./wp-public-data/$item_type/$slug.json"
if [ ! -f "$item_info_path" ]; then
    echo "$item_type $slug not found in $item_info_path"
    exit 1
fi

# Read plugin data from wp-public-data
item_info=$(cat "$item_info_path")
blueprint_url=$(echo "$item_info" | jq -r '.blueprints[0].url // empty')


# Get supported PHP versions and validate
php_version=$(echo "$item_info" | jq -r '.requires_php // empty')
supported_versions=$(jq -r '.definitions.SupportedPHPVersion.enum[]' "./node_modules/@wp-playground/blueprints/blueprint-schema.json")

# PHP 8.0 is the default because it offers support for
# a wide range of PHP extensions in Playground
# and isn't the newest version so it's more likely
# to be supported by the item.
default_php_version="8.0"

# If the PHP version is supported by Playground, use it.
# Otherwise, use the default.
php_version_major_minor=$(echo "$php_version" | cut -d'.' -f1,2)
if [ -n "$php_version" ] && echo "$supported_versions" | grep -q "^$php_version_major_minor$"; then
    php_version=$php_version_major_minor
else
    php_version=$default_php_version
fi

# Create blueprint with preferred PHP version
blueprint=$(jq -n --arg php_version "$php_version" '
    {
        "preferredVersions": {
            "php": $php_version,
            "wp": "latest"
        }
    }
')
if [ -n "$blueprint_url" ]; then
    # Use existing blueprint if available
    curl -s -o "$blueprint_path" "$blueprint_url"
elif [ "$item_type" = "plugins" ]; then
    # Create blueprint with required plugins
    requires_plugins=$(echo "$item_info" | jq -r '.requires_plugins // [] | join(", ")')
    plugins=()
    if [ -n "$requires_plugins" ]; then
        IFS=', ' read -r -a required_array <<< "$requires_plugins"
        plugins+=("${required_array[@]}")
    fi
    plugins+=("$slug")

    # Create plugin steps JSON and merge with existing blueprint
    plugin_steps=$(jq -n --arg plugins "$(printf '%s\n' "${plugins[@]}")" '
        {
            "steps": (
                $plugins | split("\n") | map({
                    "step": "installPlugin",
                    "pluginData": {
                        "resource": "wordpress.org/plugins",
                        "slug": .
                    },
                    "options": {
                        "activate": true
                    }
                })
            )
        }
    ')
    jq -s '.[0] * .[1]' <(echo "$blueprint") <(echo "$plugin_steps") > "$blueprint_path"
elif [ "$item_type" = "themes" ]; then
    # Similar changes for themes...
    requires_themes=$(echo "$item_info" | jq -r '.requires_themes // [] | join(", ")')
    themes=()
    if [ -n "$requires_themes" ]; then
        IFS=', ' read -r -a required_array <<< "$requires_themes"
        themes+=("${required_array[@]}")
    fi
    themes+=("$slug")

    # Create theme steps JSON and merge with existing blueprint
    theme_steps=$(jq -n --arg themes "$(printf '%s\n' "${themes[@]}")" '
        {
            "steps": (
                $themes | split("\n") | map({
                    "step": "installTheme",
                    "themeData": {
                        "resource": "wordpress.org/themes",
                        "slug": .
                    },
                    "options": {
                        "activate": true
                    }
                })
            )
        }
    ')
    jq -s '.[0] * .[1]' <(echo "$blueprint") <(echo "$theme_steps") > "$blueprint_path"
fi

echo "$blueprint_path"