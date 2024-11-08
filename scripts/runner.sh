#! /bin/bash

batch_size=10
item_type=""

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
      item_type="plugins"
      shift 1
      ;;
    --themes)
      item_type="themes"
      shift 1
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

run_batch() {
    echo "Running batch of ${batch_size} items..."

    # Find the oldest items to test first.
    # We use the age of the error.json file to determine the age.
    #
    # We want to check error.json files from the root of each item so we go 3 levels deep.
    # There might be more error.json files in subfolders but we ignore them.
    folders=$(find logs/$item_type/ -maxdepth 3 -mindepth 3 -type f -name "error.json" \
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
        ./scripts/save-changes.sh --add $(basename "$folder") --message "⏳ $(basename "$folder") is being tested"
    done
    ./scripts/save-changes.sh --push

    for folder in $folders; do
        ./scripts/tester.sh --$item_type "$folder"
        failed_tests=$?
        folder_name=$(basename "$folder")
        message=""
        if [ $failed_tests -gt 0 ]; then
          message="✗ $folder_name has $failed_tests errors"
        else
          message="✓ $folder_name has no errors"
        fi
        ./scripts/save-changes.sh --add "$folder" --message "$message"
    done
    ./scripts/save-changes.sh --push
}

run_batch
