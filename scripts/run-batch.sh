#! /bin/bash
#
# Run a batch of tests.
#
# Usage: ./scripts/run-batch.sh --batch-size <batch-size> --plugins|--themes
#
# --batch-size <batch-size> Number of items to test. (10 by default)
# --plugins|--themes Type of items to test.

source "./scripts/pre-script-run.sh"

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

temp_path="$(pwd)/temp"
wordpress_path="$temp_path/wordpress"
download_latest_wordpress() {
  if [ -d "$wordpress_path" ]; then
    rm -rf "$wordpress_path"
  fi
  ./scripts/build-wordpress.sh --output "$temp_path"
}

run_batch() {
    echo "Running batch of ${batch_size} items..."

    # Find the oldest items to test first.
    # We use the age of the error.json file to determine the age.
    #
    # We want to check error.json files from the root of each item so we go 4 levels deep.
    # There might be more error.json files in subfolders but we ignore them.
    folders=$(find "$PLAYGROUND_TESTER_DATA_PATH/logs/$item_type/" -maxdepth 4 -mindepth 4 -type f -name "error.json" \
        -exec ls -ltr {} + |           # Sort numerically by time modified
        head -n "$batch_size" |      # Take only the number we need
        awk '{print $NF}' |          # Get the path (last field)
        sed 's/\/error.json//')      # Remove error.json from path

    # Update all items in the current batch to prevent them from being picked up by another runner.
    #
    # We will only update the error.json file to the current time to indicate that the item is being processed
    # without making any changes to the contents of the file and losing data.
    for folder in $folders; do
        touch "$folder/error.json"
        folder_name=$(basename "$folder")
        ./scripts/save-changes.sh --add $folder --submodule logs --message "⏳ $(basename "$folder") is being tested"
    done
    ./scripts/save-changes.sh --submodule logs --push

    for folder in $folders; do
        ./scripts/run-tests.sh --$test_type $folder --wordpress "$wordpress_path"
        failed_tests=$?
        folder_name=$(basename "$folder")
        message=""
        if [ $failed_tests -gt 0 ]; then
          message="❌ $folder_name has $failed_tests errors"
        else
          message="✅ $folder_name has no errors"
        fi
        ./scripts/save-changes.sh --add "$folder" --submodule logs --message "$message"
    done
    ./scripts/save-changes.sh --submodule logs --push
}

download_latest_wordpress
run_batch
