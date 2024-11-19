#! /bin/bash
#
# This script will run the batches in Docker until it's stopped manually.
#
# Usage: ./scripts/run-batches-in-docker.sh

source "./scripts/pre-script-run.sh"

# Build the Docker image
docker build -t wordpress-test-runner .

# Get Git config from host
GIT_USER_NAME=$(git config --get user.name)
GIT_USER_EMAIL=$(git config --get user.email)

while true; do
    echo "Starting new batch in Docker..."
    docker run \
        --rm \
        -v "$(pwd):/app" \
        -v ~/.ssh/github:/root/.ssh/id_rsa \
        -v ~/.ssh/github.pub:/root/.ssh/id_rsa.pub \
        wordpress-test-runner \
        bash -c "
            PLAYGROUND_TESTER_DISABLE_GIT=true
            ./scripts/run-batch.sh --plugins --batch-size 100
        "
    echo "Batch completed. Starting next batch in 3 seconds..."
    ./scripts/save-changes.sh --push
    sleep 3
done

