#! /bin/bash
#
# Run a batch of tests.
#
# Usage: ./scripts/run-batch.sh --batch-size <batch-size> --plugins|--themes
#
# --batch-size <batch-size> Number of items to test. (10 by default)
# --plugins|--themes Type of items to test.

source "./scripts/pre-script-run.sh"
source ./scripts/save-data.sh
source ./scripts/lib/logs/analyze-json-logs.sh
source ./scripts/lib/wp-data/list-items.sh
source ./scripts/lib/logs/list-logs.sh

batch_size=10
item_type=""
test_type=""
top_n_items=""
previews=false

# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --batch-size)
      batch_size="$2"
      if ! [[ "$batch_size" =~ ^[0-9]+$ ]] ; then
        echo "Error: --batch-size argument must be a positive integer" >&2
        exit 1
      fi
      shift 2
      ;;
    --top)
      top_n_items="$2"
      shift 2
      ;;
    --previews)
      previews=true
      shift 1
      ;;
    --plugins)
      test_type="plugin"
      item_type="plugins"
      shift 1
      ;;
    --themes)
      test_type="theme"
      item_type="themes"
      shift 1
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$item_type" ]; then
  echo "Error: --plugins or --themes option is required" >&2
  exit 1
fi

download_latest_wordpress() {
  if [ -d "$PLAYGROUND_TESTER_WORDPRESS_PATH" ]; then
    rm -rf "$PLAYGROUND_TESTER_WORDPRESS_PATH"
  fi
  ./scripts/build-wordpress.sh --output "$PLAYGROUND_TESTER_TEMP_PATH"
}

run_batch_items() {
    local batch_items=$1
    # Update all items in the current batch to prevent them from being picked up by another runner.
    #
    # We will only update the error.json file to the current time to indicate that the item is being processed
    # without making any changes to the contents of the file and losing data.

    for batch_item in $batch_items; do
        touch "$batch_item/error.json"
        local folder_name=$(basename "$batch_item")
        save_data --add "$batch_item" --message "⏳ $(basename "$batch_item") is being tested"
    done
    save_data --push

    for batch_item in $batch_items; do
        ./scripts/run-tests.sh --$test_type $batch_item --wordpress "$PLAYGROUND_TESTER_WORDPRESS_PATH"
        local failed_tests=$?
        local folder_name=$(basename "$batch_item")
        local message=""
        if [ $failed_tests -gt 0 ]; then
          message="❌ $folder_name has $failed_tests errors"
        else
          message="✅ $folder_name has no errors"
        fi
        save_data --add "$batch_item" --message "$message"
    done
    save_data --push
}

run_batches() {
  local batch_items=$1
  local index=0

  local items_array=($batch_items)
  local total_items=${#items_array[@]}

  while [ $index -lt $total_items ]; do
    local current_batch=""
    local batch_end=$((index + batch_size))
    for ((i=index; i<batch_end && i<total_items; i++)); do
      current_batch+="${items_array[i]} "
    done

    run_batch_items "$current_batch"

    index=$batch_end
  done
}

run_top_n_items() {
  echo "Running top $top_n_items items..."
  run_batches "$(list_log_paths_for_slugs $item_type "$(list_top_n_items $item_type $top_n_items)")"
}

run_plugin_previews() {
  echo "Testing WordPress.org $item_type previews..."
  run_batches "$(list_log_paths_for_slugs $item_type "$(list_plugins_with_previews)")"
}

run_batch() {
  echo "Running batch of ${batch_size} items..."
  # Find the oldest items to test first.
  # We use the age of the error.json file to determine the age.
  local batch_items=$(get_log_files "$item_type" \
      -exec ls -ltr {} + |           # Sort numerically by time modified
      head -n "$batch_size" |      # Take only the number we need
      awk '{print $NF}' |          # Get the path (last field)
      sed 's/\/error.json//')      # Remove error.json from path
  run_batch_items "$batch_items"
}

download_latest_wordpress

if [ -n "$top_n_items" ]; then
  run_top_n_items
elif [ "$previews" = true ]; then
  run_plugin_previews
else
  run_batch
fi

