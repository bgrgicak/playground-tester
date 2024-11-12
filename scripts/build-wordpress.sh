#! /bin/bash
#
# Build a snapshot of WordPress using the Playground CLI.
# This snapshot can be mounted to the Playground CLI when running tests.
#
# Usage:
#   ./scripts/build-wordpress.sh --output <path>
#
# --output <path> Path to the folder where the WordPress snapshot will be saved.

source "./scripts/pre-script-run.sh"

wordpress_path=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --output) wordpress_path="$2"; shift 2;;
        *) echo "Unknown option: $1"; exit 1;;
    esac
done

if [ -z "$wordpress_path" ]; then
    echo "Error: --output <path> is a required argument."
    exit 1
fi

mkdir -p "$wordpress_path"
rm -rf "$wordpress_path/wordpress" "$wordpress_path/latest.zip"
node "$PLAYGROUND_CLI_PATH" build-snapshot \
    --quiet \
    --wp="https://wordpress.org/latest.zip" \
    --outfile="$wordpress_path/latest.zip"
unzip "$wordpress_path/latest.zip" -d "$wordpress_path"
rm "$wordpress_path/latest.zip"
echo "$wordpress_path/wordpress"