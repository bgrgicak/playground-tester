#! /bin/bash

source "./scripts/pre-script-run.sh"

# List the top N items by active installs and downloads
# The output is a list of slugs
#
# Usage:
#   list_top_n_items <item_type> <top_n_items>
#
# Example:
#   list_top_n_items plugins 10
list_top_n_items() {
  local item_type=$1
  local top_n_items=$2

  find "wp-public-data/$item_type" -name '*.json' -exec cat {} + | \
    jq -s -r '
        map({slug, name, requires_plugins, requires, active_installs: (.active_installs // 0), downloads: (.downloaded // 0)}) |
        sort_by(-.active_installs, -.downloads) |
        .[:'$top_n_items'] |
        .[].slug
    '
}

# List plugins with previews
#
# Usage:
#   list_plugins_with_previews
list_plugins_with_previews() {
  find "wp-public-data/plugins" -name '*.json' -exec cat {} + | \
    jq -s -r '
        .[] |
        select(.blueprints | length > 0) |
        .slug
    '
}

