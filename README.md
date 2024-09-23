# WordPress Playground compatibility tester 

This script checks if plugins from WordPress.org are compatible with WordPress Playground.
Plugins are sorted by active installs and downloads starting from the most popular ones.

[Playground Error Report](reports/playground_stats.md) are generated daily and pushed to the `reports` folder.

[SQL Errors Report](reports/sql-errors.md)

[PHP Errors Report](reports/php-errors.md)

[Plugin logs](logs/) are generated daily and pushed to the `logs` folder. Each plugin has its own log file with errors from the last run. Use git history to see previous days logs.

## Dependencies

- Bash shell (available by default on most Unix-based systems, including Linux and macOS)
- [`git`](https://git-scm.com/) version control system
- [`jq`](https://stedolan.github.io/jq/): command-line JSON processor
- [`bun`](https://bun.sh/): JavaScript runtime and toolkit

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
