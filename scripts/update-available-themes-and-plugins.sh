#! /bin/bash

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

update_wp_public_data
update_list_of_items_to_test "wp-public-data/plugins" "plugins"
update_list_of_items_to_test "wp-public-data/themes" "themes"

./scripts/save-changes.sh --add logs/ --message "Updated the list of plugins and themes on $(date +"%Y-%m-%d")" --push