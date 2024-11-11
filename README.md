# Playground compatibility tester

This script checks if plugins from WordPress.org are compatible with WordPress Playground.
Plugins are sorted by active installs and downloads starting from the most popular ones.

[Playground Error Report](reports/playground_stats.md) are generated daily and pushed to the `reports` folder.

[SQL Errors Report](reports/sql-errors.md)

[PHP Errors Report](reports/php-errors.md)

[Plugin logs](logs/) are generated daily and pushed to the `logs` folder. Each plugin has its own log file with errors from the last run. Use git history to see previous days logs.


## Overview

- `updater.sh` - Updates the list of plugins and themes (soon) to test. The update runs daily.
- `runner.sh` - Tests a batch of items that haven't been tested for the longest time. It runs continuously.
   - `tester.sh` - Tests a single item and can run multiple tests.
      - `blueprint-builder.sh` - Builds a base blueprint for the item.
      - Test script are located in `tests/[test-name].sh`.
      - Raw results are stored in `logs/(plugin|theme)/[slug]/[test-name]/error.log`.
      - Parsed results are stored in `logs/(plugin|theme)/[slug]/[test-name]/error.json`.
      - A report for the plugin/theme is generated in `logs/(plugin|theme)/[slug]/[test-name]/report.md`.
      - After every test run new logs are pushed to git.
   - `parser.sh` - Parses the logs and extracts errors. It runs at the end of `tester.sh`.
- `reporter.sh` - Generates a report from the logs. It runs daily and uses the current state of the logs.


## Dependencies

- Bash shell (available by default on most Unix-based systems, including Linux and macOS)
- [`git`](https://git-scm.com/) version control system
- [`jq`](https://stedolan.github.io/jq/): command-line JSON processor
- [`node`](https://nodejs.org/en): JavaScript runtime
- [`nvm`](https://github.com/nvm-sh/nvm): Node Version Manager (it's shipped with the project in the `.nvm` folder)
## Installation

1. Clone the repository:
   ```
   git clone https://github.com/bgrgicak/playground-tester.git
   ```
2. Install dependencies:
   ```
   bun install
   ```

## Running the Script

1. Make sure the script is executable:
   ```
   chmod +x tester.sh
   ```

2. Run the script:
   ```
   ./tester.sh
   ```

## Options

- `-n`: Number of plugins to test.
- `-p`: Plugin name to test.

