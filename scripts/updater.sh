#! /bin/bash

echo "Updating the list of plugins and themes..."

update_wp_public_data() {
    # Check if wp-public-data folder exists
    # If the folder does not exist, clone the repository from GitHub.
    if [ ! -d "wp-public-data" ]; then
        echo "wp-public-data folder not found. Cloning from GitHub..."
        git clone https://github.com/dd32/wp-public-data
        if [ $? -eq 0 ]; then
            echo "Successfully cloned wp-public-data repository."
        else
            echo "Failed to clone wp-public-data repository. Exiting."
            exit 1
        fi
    # If the folder exists, check if it is up to date.
    else
        echo "wp-public-data folder already exists. Checking for updates..."
        cd wp-public-data
        git fetch origin trunk
        if [ $(git rev-parse HEAD) != $(git rev-parse @{u}) ]; then
            echo "Updates available. Pulling changes..."
            git pull origin trunk
            if [ $? -eq 0 ]; then
                echo "Successfully updated wp-public-data repository."
            else
                echo "Failed to update wp-public-data repository."
            fi
        else
            echo "Repository is up to date."
        fi
        cd ..
    fi
}

update_list_of_items_to_test() {
    local src_dir=$1
    local item_type=$2

    echo "Adding items from ${src_dir}..."

    for item in $(ls "${src_dir}"); do
        item=$(echo $item | sed 's/.json//')
        local log_dir="logs/${item_type}/${item}"

        if [ ! -d "$log_dir" ]; then
            echo "Adding missing log files for ${item} to ${item_type}..."
            mkdir -p "$log_dir"

            # Placeholder for the README file that will be replaced after the first test run
            echo "# Playground tests for ${item}" > "${log_dir}/README.md"
            echo "We are still awaiting the first test run for ${item}." >> "${log_dir}/README.md"
        fi
    done
}

update_wp_public_data
update_list_of_items_to_test "wp-public-data/plugins" "plugins"
update_list_of_items_to_test "wp-public-data/themes" "themes"
