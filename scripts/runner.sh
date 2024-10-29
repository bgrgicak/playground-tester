#! /bin/bash

batch_size=10

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
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

run_batch() {
    echo "Running batch of ${batch_size} items..."

    # Find the oldest items to test first
    # We use the age of the README.md file to determine the age
    #
    # We currently only test plugins, so we only look at the plugins folder
    # TODO: Add support for themes
    folders=$(find logs/plugins -type f -name "README.md" -ls |
        sort -k8,9 |
        head -n "$batch_size" |
        awk '{print $NF}' |
        sed 's/\/README.md//')

    for folder in $folders; do
        ./scripts/tester.sh --plugin "$folder"
    done
}

run_batch
