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

new_steps_file=$(mktemp)
cat > "$new_steps_file" << 'EOL'
[
    {
      "step": "defineWpConfigConsts",
      "consts": {
        "WP_SQLITE_AST_DRIVER": true
      }
    },
    {
      "step": "installPlugin",
      "pluginData": {
        "resource": "url",
        "url": "https://github-proxy.com/proxy/?repo=Automattic/sqlite-database-integration&branch=develop"
      },
      "options": {
        "activate": false
      }
    },
    {
      "step": "rmdir",
      "path": "/internal/shared/sqlite-database-integration"
    },
    {
      "step": "mv",
      "fromPath": "/wordpress/wp-content/plugins/sqlite-database-integration-develop",
      "toPath": "/internal/shared/sqlite-database-integration"
    }
]
EOL


asl_blueprint_path=$(mktemp)
jq -s '.[0] as $new | .[1] | .steps = ($new + .steps)' "$new_steps_file" "$blueprint_path" > "$asl_blueprint_path"

# The new SQLite driver doesn't support PHP 7.2 or 7.3, so we need to update the PHP version to 7.4
jq '.preferredVersions.php = (if .preferredVersions.php == "7.2" or .preferredVersions.php == "7.3" then "7.4" else .preferredVersions.php end)' "$asl_blueprint_path" > "${asl_blueprint_path}.tmp" && mv "${asl_blueprint_path}.tmp" "$asl_blueprint_path"

wordpress_args=""
if [ -n "$wordpress_path" ]; then
  wordpress_args=" --skipWordPressSetup --mountBeforeInstall $wordpress_path:/wordpress"
fi

node node_modules/@wp-playground/cli/cli.js run-blueprint --quiet --debug --blueprint="$asl_blueprint_path" --port ${PLAYGROUND_PORT:-9400} $wordpress_args 2>&1
