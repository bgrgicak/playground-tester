#!/bin/bash

check_dependencies() {
    if ! command -v git &> /dev/null
    then
        echo "git could not be found. Please install git to run this script."
        echo "On Ubuntu/Debian: sudo apt-get install git"
        echo "On macOS with Homebrew: brew install git"
        exit 1
    fi

    if ! command -v jq &> /dev/null
    then
        echo "jq could not be found. Please install jq to run this script."
        echo "On Ubuntu/Debian: sudo apt-get install jq"
        echo "On macOS with Homebrew: brew install jq"
        exit 1
    fi

    if ! command -v bun &> /dev/null
    then
        echo "Bun could not be found. Please install Bun to run this script."
        echo "Visit https://bun.sh for installation instructions."
        exit 1
    fi
}

# Generate test data from wp-public-data
# This function will create a JSON file with the name and slug of each plugin that is available in the wp-public-data repository.
generate_test_data() {
    echo "Generating test data..."
    find wp-public-data/plugins -name '*.json' -exec cat {} + | jq -s 'map({name, slug, requires_plugins})' > plugins-to-test.json
    echo "Test data generated successfully."
}

prepare_environment() {
    local generate_data=false

    # Check if wp-public-data folder exists
    # If the folder does not exist, clone the repository from GitHub.
    if [ ! -d "wp-public-data" ]; then
        echo "wp-public-data folder not found. Cloning from GitHub..."
        git clone https://github.com/dd32/wp-public-data
        if [ $? -eq 0 ]; then
            echo "Successfully cloned wp-public-data repository."
            repo_updated=true
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
                repo_updated=true
            else
                echo "Failed to update wp-public-data repository."
            fi
        else
            echo "Repository is up to date."
        fi
        cd ..
    fi

    # Check if plugins-to-test.json needs to be generated
    if [ ! -f "plugins-to-test.json" ] || [ "$repo_updated" = true ]; then
        generate_test_data
    else
        echo "plugins-to-test.json already exists and is up to date."
    fi
}

cleanup() {
    rm -f error_log.txt
}

run_tests() {
    echo "Running tests..."

    jq -r '.[] | {slug: .slug, requires_plugins: (.requires_plugins // [])} | @json' plugins-to-test.json | while read -r plugin_info; do
        slug=$(echo "$plugin_info" | jq -r '.slug')
        requires_plugins=$(echo "$plugin_info" | jq -r '.requires_plugins | join(", ")')

        plugins=()
        if [ -n "$requires_plugins" ]; then
            IFS=', ' read -r -a required_array <<< "$requires_plugins"
            plugins+=("${required_array[@]}")
        fi
        plugins+=("$slug")
        plugins_json=$(printf '%s\n' "${plugins[@]}" | jq -R . | jq -s .)

        echo "{ \"plugins\": $plugins_json }" > blueprint.json
        output=$(bun node_modules/@wp-playground/cli/cli.js run-blueprint --blueprint=blueprint.json 2>&1)
        if echo "$output" | grep -q "Blueprint executed"; then
            echo "Plugin $slug: Success"
        else
            echo "Plugin $slug: Error"
            echo "$output" >> error_log.txt
            echo "$slug" >> failed_plugins.txt
        fi
    done
}

check_dependencies
prepare_environment
cleanup
run_tests