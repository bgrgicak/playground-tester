#! /bin/bash
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
  esac
done

if [ -z "$blueprint_path" ]; then
    exit 1
fi

# Use Node 23 which supports JSPI
nvm install 23 >/dev/null 2>&1

wordpress_args=""
if [ -n "$wordpress_path" ]; then
  wordpress_args=" --skipWordPressSetup --mountBeforeInstall $wordpress_path:/wordpress"
fi

output=$(node --experimental-wasm-jspi ./node_modules/@wp-playground/cli/cli.js run-blueprint --quiet --debug --blueprint="$blueprint_path" $wordpress_args 2>&1)

# Switch back to the node version specified in .nvmrc
nvm install $(cat .nvmrc) >/dev/null 2>&1

echo "$output"
