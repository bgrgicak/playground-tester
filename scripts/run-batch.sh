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

run_batch() {
    echo "Running batch of ${batch_size} items..."

    # Find the oldest items to test first.
    echo "[DEBUG]: Starting get_first_n_logs_to_test"
    local folders=$(get_first_n_logs_to_test "$item_type" "$batch_size")
    echo "[DEBUG]: Done get_first_n_logs_to_test"

    # Update all items in the current batch to prevent them from being picked up by another runner.
    #
    # We will only replace the TIMESTAMP-last-tested.txt file to indicate that the item is being processed.
    for folder in $folders; do
        local timestamp_files=$(find "$folder" -name "*-last-tested.txt")
        for timestamp_file in $timestamp_files; do
            rm "$timestamp_file"
        done
        echo "Last tested on $(date +%Y-%m-%d\ %H:%M:%S)" > "$folder/$(date +%Y%m%d-%H%M%S)-last-tested.txt"
    done
    echo "[DEBUG]: Starting save_data: a batch is being tested"
    save_data --add "*" --message "⏳ a $item_type batch is being tested"
    echo "[DEBUG]: Done save_data"

    echo "[DEBUG]: Starting save_data --push"
    save_data --push || exit 1
    echo "[DEBUG]: Done save_data"

    for folder in $folders; do
        echo "[DEBUG]: Starting run-tests.sh $test_type $folder"
        ./scripts/run-tests.sh --$test_type $folder --wordpress "$PLAYGROUND_TESTER_WORDPRESS_PATH"
        echo "[DEBUG]: Done run-tests.sh"
        local failed_tests=$?
        local folder_name=$(basename "$folder")
        local message=""
        if [ $failed_tests -gt 0 ]; then
          message="❌ $folder_name has $failed_tests errors"
        else
          message="✅ $folder_name has no errors"
        fi
        echo "[DEBUG]: Starting save_data --add $folder $message"
        save_data --add "$folder" --message "$message"
        echo "[DEBUG]: Done save_data"
    done
    echo "[DEBUG]: Starting save_data --push"
    save_data --push || exit 1
    echo "[DEBUG]: Done save_data"
}

echo "[DEBUG]: Starting download_latest_wordpress"
download_latest_wordpress
echo "[DEBUG]: Starting run_batch"
run_batch