#! /bin/bash
#
# This script will run the batches in Docker until it's stopped manually.
#
# Usage: ./scripts/run-batches-in-docker.sh

source "./scripts/pre-script-run.sh"

docker build -t wordpress-test-runner .

while true; do
    echo "Starting new batch in Docker..."
    docker run \
        --rm \
        -v "$(pwd):/app" \
            wordpress-test-runner \
            ./scripts/run-batch.sh --plugins --batch-size 10
    echo "Batch completed. Starting next batch in 3 seconds..."
    sleep 3
done

