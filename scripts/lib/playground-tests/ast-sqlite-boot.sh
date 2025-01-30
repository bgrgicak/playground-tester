#! /bin/bash

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
    "step": "mkdir",
    "path": "wordpress/wp-content/mu-plugins"
  },
  {
    "step": "writeFile",
    "path": "wordpress/wp-content/mu-plugins/addFilter-0.php",
    "data": "<?php function sqlite_plugin_adminbar_item( $admin_bar ) {\nglobal $wpdb;\n$suffix = defined( 'WP_SQLITE_AST_DRIVER' ) && WP_SQLITE_AST_DRIVER ? ' (AST)' : '';\n$title  = '<span style=\"color:%2346B450;\">' . __( 'Database: SQLite', 'sqlite-database-integration' ) . $suffix . '</span>';\n$args = array(\n'id'     => 'sqlite-db-integration',\n'parent' => 'top-secondary',\n'title'  => $title,\n'href'   => esc_url( admin_url( 'options-general.php?page=sqlite-integration' ) ),\n'meta'   => false,\n);\n$admin_bar->add_node( $args );\n}\nadd_action( 'admin_bar_menu', 'sqlite_plugin_adminbar_item', 999 );"
  },
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
      "url": "https://github-proxy.com/proxy/?repo=Automattic/sqlite-database-integration&branch=ast-sqlite-driver-beta"
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
    "fromPath": "/wordpress/wp-content/plugins/sqlite-database-integration-ast-sqlite-driver-beta",
    "toPath": "/internal/shared/sqlite-database-integration"
  }
]
EOL


asl_blueprint_path=$(mktemp)
jq -s '.[0] as $new | .[1] | .steps = ($new + .steps)' "$new_steps_file" "$blueprint_path" > "$asl_blueprint_path"

# Use Node if it's not already installed
nvm install $(cat .nvmrc) >/dev/null 2>&1

wordpress_args=""
if [ -n "$wordpress_path" ]; then
  wordpress_args=" --skipWordPressSetup --mountBeforeInstall $wordpress_path:/wordpress"
fi

node node_modules/@wp-playground/cli/cli.js run-blueprint --quiet --debug --blueprint="$asl_blueprint_path" $wordpress_args 2>&1
