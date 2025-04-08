#! /bin/bash
set -e

source "./scripts/pre-script-run.sh"

blueprint_path=""
wordpress_path=""
# Parse command line options
while [[ "$#" -gt 0 ]]; do
  case $1 in
    --blueprint)
      blueprint_path="$2"
      shift 2
      ;;
    --wordpress)
      wordpress_path="$2"
      shift 2
      ;;
    *)
      echo "Invalid option: $1" >&2
      exit 1
      ;;
  esac
done

if [ -z "$blueprint_path" ]; then
    exit 1
fi

wordpress_args=""
if [ -n "$wordpress_path" ]; then
  wordpress_args=" --skipWordPressSetup --mountBeforeInstall $wordpress_path:/wordpress"
fi

node --experimental-wasm-jspi ./node_modules/@wp-playground/cli/cli.js run-blueprint --quiet --debug --blueprint="$blueprint_path" --port ${PLAYGROUND_PORT:-9400} $wordpress_args 2>&1
