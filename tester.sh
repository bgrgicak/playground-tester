#!/bin/bash

# Initialize variables
limit=""
plugin_name=""
offset=""

# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --limit)
      limit="$2"
      if ! [[ "$limit" =~ ^[0-9]+$ ]] ; then
        echo "Error: --limit argument must be a positive integer" >&2
        exit 1
      fi
      shift 2
      ;;
    --offset)
      offset="$2"
      if ! [[ "$offset" =~ ^[0-9]+$ ]] ; then
        echo "Error: --offset argument must be a positive integer" >&2
        exit 1
      fi
      shift 2
      ;;
    --plugin)
      plugin_name="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

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

    if [ -f "last-update-time.txt" ]; then
        last_update=$(cat last-update-time.txt)
    else
        last_update="1970-01-01 00:00:00"  # Unix epoch start as default
    fi

    find wp-public-data/plugins -name '*.json' -exec cat {} + | \
    jq -s --arg last_update "$last_update" '
        def parse_date:
          split(" ") | .[0] | split("-") | map(tonumber) as $ymd |
          ($ymd[0] * 10000 + $ymd[1] * 100 + $ymd[2]);
        map(select((.last_updated | parse_date) > ($last_update | parse_date)) |
            {name, slug, requires_plugins, blueprints, active_installs: (.active_installs // 0), downloads: (.downloaded // 0)}) |
        sort_by(-.active_installs, -.downloads)
    ' > plugins-to-test.json

    echo "Test data generated successfully."
}

prepare_environment() {
    if [ ! -d "logs" ]; then
        echo "Creating logs folder..."
        mkdir logs
    fi

    if [ ! -d "temp" ]; then
        echo "Creating temp folder..."
        mkdir temp
    fi

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

    generate_test_data
}

cleanup() {
    rm -f temp/*
}

run_tests() {
    echo "Running tests..."

    # Get current timestamp
    current_timestamp=$(date +"%Y-%m-%d-%H-%M-%S")

    # Check if limit and offset are set and use them to limit the number of items to test
    if [ -n "$limit" ] && [ -n "$offset" ]; then
        jq_command=".[$offset:$((offset + limit))]"
    elif [ -n "$limit" ]; then
        jq_command=".[:$limit]"
    elif [ -n "$offset" ]; then
        jq_command=".[$offset:]"
    else
        jq_command="."
    fi

    jq -r "$jq_command | .[] | {slug: .slug, requires_plugins: (.requires_plugins // []), blueprints: (.blueprints // [])} | @json" plugins-to-test.json | while read -r plugin_info; do
        slug=$(echo "$plugin_info" | jq -r '.slug')

        if [ -n "$plugin_name" ] && [ "$plugin_name" != "$slug" ]; then
            continue
        fi

        blueprint_url=$(echo "$plugin_info" | jq -r '.blueprints[0].url')

        log_file="logs/$slug"
        # Empty the log file if it exists
        if [ -f "$log_file" ]; then
            echo "" > "$log_file"
        fi

        blueprint_file_name="temp/blueprint-${slug}-${current_timestamp}.json"

        if [ "$blueprint_url" != "null" ]; then
            curl -s -o "$blueprint_file_name" "$blueprint_url"
        else
            requires_plugins=$(echo "$plugin_info" | jq -r '.requires_plugins | join(", ")')
            plugins=()
            if [ -n "$requires_plugins" ]; then
                IFS=', ' read -r -a required_array <<< "$requires_plugins"
                plugins+=("${required_array[@]}")
            fi
            plugins+=("$slug")
            plugins_json=$(printf '%s\n' "${plugins[@]}" | jq -R . | jq -s .)
            echo "{ \"plugins\": $plugins_json }" > "$blueprint_file_name"
        fi

        output=$(bun  node_modules/@wp-playground/cli/cli.js run-blueprint --quiet --debug --blueprint="$blueprint_file_name" 2>&1)
        if [ -z "$output" ]; then
            echo "Plugin $slug: Success"
            # add empty file to logs folder
            echo "" > "$log_file"
        else
            echo "Plugin $slug: Error"
            echo "$output" >> "$log_file"
        fi

        rm "$blueprint_file_name"
    done
}

update_last_update_time() {
    echo "Updating last update time..."
    date "+%Y-%m-%d 00:00:00" > last-update-time.txt
    echo "Last update time updated successfully."
}

check_dependencies
prepare_environment
run_tests
update_last_update_time
cleanup
