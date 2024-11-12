#! /bin/bash

wordpress_path="$1"

mkdir -p "$wordpress_path"
rm -rf "$wordpress_path/wordpress" "$wordpress_path/latest.zip"
node node_modules/@wp-playground/cli/cli.js build-snapshot \
    --wp="https://wordpress.org/latest.zip" \
    --outfile="$wordpress_path/latest.zip"
unzip "$wordpress_path/latest.zip" -d "$wordpress_path"
echo "$wordpress_path/wordpress"