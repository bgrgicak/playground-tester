# Playground compatibility tester

> **Warning**
> This project is in development and tests are currently not running automatically.

This project tests if plugins and themes from WordPress.org are compatible with WordPress Playground.

If you are a plugin or theme developer you can find logs for your project in the `data/logs/(plugin|theme)/[first-letter]/[slug]` folder.

You can find how the error rate is changing over time in the [Playground Error Report](data/reports/playground_stats.md).
To see the exact errors generated Playground tests, check out [SQL Errors Report](data/reports/sql-errors.md) and [PHP Errors Report](data/reports/php-errors.md).

## Overview

- `update-available-themes-and-plugins.sh` - Updates the list of plugins and themes (soon) to test. The update runs daily.
- `run-batch.sh` - Tests a batch of items that haven't been tested for the longest time. It runs continuously.
   - `run-tests.sh` - Tests a single item and can run multiple tests.
      - `generate-blueprint.sh` - Builds a base blueprint for the item.
      - Test script are located in `tests/[test-name].sh`.
      - Raw results are stored in `data/logs/(plugin|theme)/[slug]/[test-name]/error.log`.
      - Parsed results are stored in `data/logs/(plugin|theme)/[slug]/[test-name]/error.json`.
      - (Soon) A report for the plugin/theme is generated in `data/logs/(plugin|theme)/[slug]/[test-name]/report.md`.
      - After every test run new logs are pushed to git.
   - (Soon) `parser.sh` - Parses the logs and extracts errors. It runs at the end of `run-tests.sh`.
- (Soon) `reporter.sh` - Generates a report from the logs. It runs daily and uses the current state of the logs.


## Dependencies

- Bash shell (available by default on most Unix-based systems, including Linux and macOS)
- [`git`](https://git-scm.com/) version control system
- [`jq`](https://stedolan.github.io/jq/): command-line JSON processor
- [`node`](https://nodejs.org/en): JavaScript runtime
- [`nvm`](https://github.com/nvm-sh/nvm): Node Version Manager

## Installation

1. Clone the repository:
   ```
   git clone --recurse-submodules --shallow-submodules https://github.com/bgrgicak/playground-tester.git
   ```
2. Install dependencies:
   ```
   ./scripts/install-dependencies.sh
   ```
3. Install Node.js dependencies:
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

#### Run in a loop

```
while sleep 2; do ./scripts/run-batch.sh --plugins --batch-size 100; done
```

### Generate reports

```
./scripts/generate-reports.sh
```

### Run unit tests

```
./scripts/unit-tests/test.sh
```
