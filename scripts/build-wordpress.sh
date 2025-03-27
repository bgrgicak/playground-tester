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

zip_path="$wordpress_path/wordpress.zip"
mkdir -p "$wordpress_path"
rm -rf "$wordpress_path/wordpress" "$zip_path"
node "$PLAYGROUND_CLI_PATH" build-snapshot \
    --quiet \
    --wp="https://wordpress.org/latest.zip" \
    --outfile="$zip_path" > /dev/null
unzip -qq "$zip_path" -d "$wordpress_path" > /dev/null 2>&1
rm "$zip_path"

# Initialize the WordPress snapshot as a git repository,
# so we can reset any file changes before every test.
git init "$wordpress_path" > /dev/null 2>&1
git -C "$wordpress_path" add . > /dev/null 2>&1
git -C "$wordpress_path" commit -m "WordPress snapshot" > /dev/null 2>&1
