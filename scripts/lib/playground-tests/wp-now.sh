#! /bin/bash

source "./scripts/pre-script-run.sh"

stop_wp_now() {
    kill -SIGKILL $1
}

print_wp_now_output() {
    grep "^Failed to start the server:" "$1" \
        | sed 's/^Failed to start the server: //'
}

wp_now_test() {
    local blueprint_path=""
    local wordpress_path=""
    # Parse command line options
    while [[ "$#" -gt 0 ]]; do
    case $1 in
        --blueprint)
        blueprint_path="$2"
        shift 2
        ;;
        --wordpress)
        wordpress_path="$2"
        shift 2
        ;;
        *)
        echo "Invalid option: $1" >&2
        exit 1
        ;;
    esac
    done

    if [ -z "$blueprint_path" ]; then
        exit 1
    fi

    local wp_now_compatible_blueprint=$(mktemp)

    # WP-NOW doesn't support the latest Blueprint format, so we need to convert
    # pluginData to pluginZipFile and themeData to themeZipFile if they exist
    jq '
      .steps = (.steps | map(
        if .step == "installPlugin" then
          [
            {
              step: .step,
              pluginZipFile: .pluginData,
              options: .options
            }
          ]
        elif .step == "installTheme" then
          [
            {
              step: .step,
              themeZipFile: .themeData,
              options: .options
            }
          ]
        else
          .
        end
      ) | flatten)
    ' "$blueprint_path" > "$wp_now_compatible_blueprint"

    # Start WP-NOW in the background and capture its output
    local wp_now_output_log=$(mktemp)
    node ./node_modules/@wp-now/dec-2024/cli.js start \
        --php=8.0 \
        --blueprint="$wp_now_compatible_blueprint" \
        --skip-browser \
        > "$wp_now_output_log" 2>&1 &
    local wp_now_pid=$!

    trap "stop_wp_now $wp_now_pid" EXIT

    # Monitor the output for success or failure
    local timeout=30
    local start_time=$SECONDS
    while [ $(( SECONDS - start_time )) -lt $timeout ]; do
        if [ ! -f "$wp_now_output_log" ]; then
            sleep 1
            continue
        fi

        while IFS= read -r line; do
            if [[ "$line" == "Server running at"* ]]; then
                stop_wp_now $wp_now_pid
                exit 0
            elif [[ "$line" == "Failed to start the server"* ]]; then
                stop_wp_now $wp_now_pid
                print_wp_now_output "$wp_now_output_log"
                exit 1
            fi
        done < "$wp_now_output_log"

        sleep 1
    done

    stop_wp_now $wp_now_pid
    cat "$wp_now_output_log"
    exit 1
}

wp_now_test "$@"