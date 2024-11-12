# Playground compatibility tester

> **Warning**
> This project is in development and tests are currently not run automatically.

This script checks if plugins from WordPress.org are compatible with WordPress Playground.
Plugins are sorted by active installs and downloads starting from the most popular ones.

[Playground Error Report](reports/playground_stats.md) are generated daily and pushed to the `reports` folder.

[SQL Errors Report](reports/sql-errors.md)

[PHP Errors Report](reports/php-errors.md)

[Plugin logs](logs/) are generated daily and pushed to the `logs` folder. Each plugin has its own log file with errors from the last run. Use git history to see previous days logs.


## Overview

- `update-available-themes-and-plugins.sh` - Updates the list of plugins and themes (soon) to test. The update runs daily.
- `run-batch.sh` - Tests a batch of items that haven't been tested for the longest time. It runs continuously.
   - `run-tests.sh` - Tests a single item and can run multiple tests.
      - `generate-blueprint.sh` - Builds a base blueprint for the item.
      - Test script are located in `tests/[test-name].sh`.
      - Raw results are stored in `logs/(plugin|theme)/[slug]/[test-name]/error.log`.
      - Parsed results are stored in `logs/(plugin|theme)/[slug]/[test-name]/error.json`.
      - (Soon) A report for the plugin/theme is generated in `logs/(plugin|theme)/[slug]/[test-name]/report.md`.
      - After every test run new logs are pushed to git.
   - (Soon) `parser.sh` - Parses the logs and extracts errors. It runs at the end of `run-tests.sh`.
- (Soon) `reporter.sh` - Generates a report from the logs. It runs daily and uses the current state of the logs.


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
   npm install
   ```

## Running scripts

### Update available themes and plugins

```
./scripts/update-available-themes-and-plugins.sh
```

### Run a batch of tests

#### Plugins

```
./scripts/run-batch.sh --batch-size 100 --plugins
```

#### Themes

```
./scripts/run-batch.sh --batch-size 100 --themes
```

### Generate reports

```
./scripts/generate-reports.sh
```


