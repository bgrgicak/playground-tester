#!/bin/bash
#
# This script will update the `data/log-messages.json` file with the current log messages.
#
# Usage: ./scripts/update-log-message-data.sh

source "$(dirname "$0")/pre-script-run.sh"

log_messages_file="data/log-messages.json"

update_log_message_data() {
    temp_file=$(mktemp)
    # Combine all non empty log files
    for log_file in $(find logs/*/*/ -name "error.json" -mindepth 2 -maxdepth 2 -type f -size +3c)
    do
        jq -s 'add' "$log_file" >> "$temp_file"
    done
    mv "$temp_file" "$log_messages_file"
}

update_log_message_data