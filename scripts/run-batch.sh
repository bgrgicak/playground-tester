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
    # We use the age of the error.json file to determine the age.
    local folders=$(sort_logs_by_last_commit_date "$item_type" "$batch_size")

    # Update all items in the current batch to prevent them from being picked up by another runner.
    #
    # We will only update the error.json file to the current time to indicate that the item is being processed
    # without making any changes to the contents of the file and losing data.

    for folder in $folders; do
        touch "$folder/error.json"
        local folder_name=$(basename "$folder")
        save_data --add "$folder" --message "⏳ $(basename "$folder") is being tested"
    done
    save_data --push || exit 1

    for folder in $folders; do
        ./scripts/run-tests.sh --$test_type $folder --wordpress "$PLAYGROUND_TESTER_WORDPRESS_PATH"
        local failed_tests=$?
        local folder_name=$(basename "$folder")
        local message=""
        if [ $failed_tests -gt 0 ]; then
          message="❌ $folder_name has $failed_tests errors"
        else
          message="✅ $folder_name has no errors"
        fi
        save_data --add "$folder" --message "$message"
    done
    save_data --push || exit 1
}

download_latest_wordpress
run_batch