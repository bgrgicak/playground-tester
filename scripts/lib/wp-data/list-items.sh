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
    jq -s '
        map({slug, name, requires_plugins, requires, active_installs: (.active_installs // 0), downloads: (.downloaded // 0)}) |
        sort_by(-.active_installs, -.downloads) |
        .[:'$top_n_items']
    '
}

list_top_n_item_slugs() {
  local item_type=$1
  local top_n_items=$2

  list_top_n_items $item_type $top_n_items | jq -r '.[].slug'
}
