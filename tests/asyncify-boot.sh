#! /bin/bash

blueprint_path=""
# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --blueprint)
      blueprint_path="$2"
      shift 2
      ;;
  esac
done

if [ -z "$blueprint_path" ]; then
    exit 1
fi

# Run the test using wp-playground CLI
output=$(bun node_modules/@wp-playground/cli/cli.js run-blueprint --quiet --debug --blueprint="$blueprint_path" 2>&1)

echo $output