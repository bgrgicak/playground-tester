#! /bin/bash

source "./scripts/pre-script-run.sh"

# List log paths for slugs
#
# Usage:
#   list_log_paths_for_slugs <item_type> <slugs>
#
# Example:
#   list_log_paths_for_slugs plugins "plugin-slug"
list_log_paths_for_slugs() {
  local item_type=$1
  local slugs=$2

  for slug in $(echo "$slugs"); do
    local first_letter=$(echo "$slug" | cut -c1 | tr '[:upper:]' '[:lower:]')
    echo "$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/$first_letter/$slug"
  done
}
