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
source ./scripts/lib/log-parser/analyze-json-logs.sh
batch_size=10
item_type=""
test_type=""
top_n_items=""

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

run_top_n_items() {
  echo "Running top $top_n_items items..."

  local top_items=$(find "wp-public-data/$item_type" -name '*.json' -exec cat {} + | \
    jq -s '
        map({slug, active_installs: (.active_installs // 0), downloads: (.downloaded // 0)}) |
        sort_by(-.active_installs, -.downloads) |
        .[:'$top_n_items']
    '
  )

  local batch_items=$(mktemp)
  for item in $(echo "$top_items" | jq -r '.[].slug'); do
    local first_letter=$(echo "$item" | cut -c1 | tr '[:upper:]' '[:lower:]')
    echo "$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/$first_letter/$item" >> "$batch_items"
  done

  # Run batches of batch_size items
  local index=0
  while [ $index -lt $(wc -l < "$batch_items") ]; do
    local batch_items_batch=$(tail -n +$((index + 1)) "$batch_items" | head -n "$batch_size")
    run_batch_items "$batch_items_batch"
    index=$((index + batch_size))
  done
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
else
  run_batch
fi
