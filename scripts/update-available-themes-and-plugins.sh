#! /bin/bash
#
# Update the list of plugins and themes that are available for testing.
#
# The list of items is sourced from the https://github.com/dd32/wp-public-data repository.
#
# This script will update the list of plugins and themes from wp-public-data to ensure all items are available for testing.
# It will also create a initial error.json log file for new items.
#
# If a item is removed from wp-public-data, it will be removed from the logs.

source "./scripts/pre-script-run.sh"

echo "Updating the list of plugins and themes..."

update_wp_public_data() {
    # Check if wp-public-data submodule exists
    if [ ! -d "wp-public-data" ]; then
        echo "wp-public-data submodule not found. Initializing..."
        # Force add the submodule even if it's in .gitignore
        git submodule add -f https://github.com/dd32/wp-public-data
        git submodule update --init --recursive
        if [ $? -eq 0 ]; then
            echo "Successfully initialized wp-public-data submodule."
        else
            echo "Failed to initialize wp-public-data submodule. Exiting."
            exit 1
        fi
    # If the submodule exists, update it
    else
        echo "wp-public-data submodule exists. Updating..."
        git submodule update --remote --recursive wp-public-data
        if [ $? -eq 0 ]; then
            echo "Successfully updated wp-public-data submodule."
        else
            echo "Failed to update wp-public-data submodule."
        fi
    fi
}

update_list_of_items_to_test() {
    local src_dir=$1
    local item_type=$2

    echo "Adding items from ${src_dir}..."

    for item in $(ls "${src_dir}"); do
        item=$(echo $item | sed 's/.json//')
        first_letter=$(echo "${item:0:1}")
        local log_dir="logs/${item_type}/${first_letter}/${item}"

        if [ ! -d "$log_dir" ]; then
            echo "Adding missing log files for ${item} to ${item_type}..."
            mkdir -p "$log_dir"

            # We use the error.json to determine when was the last test run for the item
            # This will add the new item to the end of the queue
            echo "[]" > "${log_dir}/error.json"
        fi
    done
}

remove_items_not_in_wp_public_data() {
    local item_type=$1
    for item in $(ls logs/${item_type}/*); do
        if [ ! -f "wp-public-data/${item_type}/${item}.json" ]; then
            echo "Removing ${item} from ${item_type}..."
            rm -rf "logs/${item_type}/${item}"
        fi
    done
}

# update_wp_public_data
update_list_of_items_to_test "wp-public-data/plugins" "plugins"
update_list_of_items_to_test "wp-public-data/themes" "themes"
remove_items_not_in_wp_public_data "plugins"
remove_items_not_in_wp_public_data "themes"

./scripts/save-changes.sh --add logs/ --message "Updated the list of plugins and themes on $(date +"%Y-%m-%d")" --push