/**
 * Run all plugin tests from "wp-public-data" using the Playground Tester.
 * Use up to MAX_CONCURRENCY workers to execute the tests concurrently.
 */
import { exec as execCallback } from 'child_process';
import { dirname, join, resolve } from 'path';
import { promisify } from 'util';
import yargs from 'yargs';
import { startVitest, parseCLI } from 'vitest/node';
import type { Vitest } from 'vitest/node';
import { existsSync, mkdirSync, writeFileSync } from 'fs';

const exec = promisify(execCallback);

function formatTestResult(result: Vitest, slug: string): string {
    const files = result.state.getFiles();

    // Check if all tests passed
    const allPassed = files.every(file => file.result?.state === 'pass');

    if (allPassed) {
        return `✅ ${slug} passed`;
    }

    // Collect failed tests
    const failedTests: Array<{ name: string; error: string }> = [];
    let passedTests = 0;

    for (const file of files) {
        const collectTests = (task: any) => {
            if (task.type === 'test') {
                if (task.result?.state === 'pass') {
                    passedTests++;
                } else if (task.result?.state === 'fail') {
                    // Get the first line of the error message
                    const errorMessage = task.result?.errors?.[0]?.message || 'Unknown error';
                    const firstLine = errorMessage.split('\n')[0];
                    failedTests.push({
                        name: task.name,
                        error: firstLine
                    });
                }
            }

            // Recursively check nested tasks (suites)
            if (task.tasks && task.tasks.length > 0) {
                task.tasks.forEach(collectTests);
            }
        };

        // Start from the file itself
        collectTests(file);
    }

    const failedCount = failedTests.length;

    // Format output
    let output = `❌ ${slug} (${failedCount} failed, ${passedTests} passed)`;
    for (const test of failedTests) {
        output += `\n  • ${test.name} - ${test.error}`;
    }

    return output;
}

// Parse command line arguments.
const argv = yargs(process.argv.slice(2))
  .option('plugins', {
    type: 'boolean',
    description: 'Run tests for plugins',
    conflicts: 'themes',
  })
  .option('themes', {
    type: 'boolean',
    description: 'Run tests for themes',
    conflicts: 'plugins',
  })
  .option('limit', {
    type: 'number',
    description: 'Number of least recently tested items to test',
    default: 100
  })
  .option('prefix-chars', {
    type: 'string',
    description: 'Prefix characters to filter items by',
  })
  .option('dry-run', {
    type: 'boolean',
    description: 'Skip committing and pushing the results',
  })
  .option('item-path', {
    type: 'string',
    description: 'Path to the item to test',
  })
  .check((argv) => {
    if (!argv.plugins && !argv.themes) {
      throw new Error('Either --plugins or --themes must be specified');
    }
    return true;
  })
  .help()
  .parseSync();

// Configuration.
const rootDir = join(import.meta.dirname, '..');
const MAX_CONCURRENCY = 8;
const type = argv.plugins ? 'plugins' : 'themes';
const limit = argv.limit;
const prefixChars = argv['prefix-chars'];
const dryRun = !!argv['dry-run'];
const itemPath = argv['item-path'];
const {
    filter: vitestFilter,
    options: vitestBaseOptions,
} = parseCLI(['vitest', 'run', '--reporter=json']);

let paths: string[] = [];
if (itemPath) {
    paths = [resolve(rootDir, itemPath)];
} else {
    // Get plugins/themes to test.
    const findResult = await exec(
        `. ./scripts/lib/log-parser/analyze-json-logs.sh && get_first_n_logs_to_test "${type}" "${limit}" --prefix-chars "${prefixChars}"`,
        {
            cwd: rootDir,
            shell: 'bash',
            maxBuffer: 100 * 1024 * 1024,
        }
    );
    paths = findResult.stdout.split('\n').filter(Boolean);
}

// Update all items in the current batch to prevent them from being picked up by another runner.
// We will only replace the TIMESTAMP-last-tested.txt file to indicate that the item is being processed.
for (const path of paths) {
    await exec(`rm ${path}/*-last-tested.txt 2>/dev/null || true`);
    await exec(`echo "Last tested on \$(date +%Y-%m-%d\\ %H:%M:%S)" > "${path}/$(date +%Y%m%d-%H%M%S)-last-tested.txt"`);
}
if (!dryRun) {
    await exec(
        `. ./scripts/save-data.sh && save_data --add . --message "⏳ testing a batch of ${limit} ${type}" --push`,
        { cwd: rootDir, shell: 'bash' }
    );
}

// Run tests for plugins/themes batch.
const pool = new Array(MAX_CONCURRENCY).fill(undefined);

for (const path of paths) {
    const workers = pool.filter((slot) => slot !== undefined);
    if (workers.length >= pool.length) {
        await Promise.race(workers);
    }

    const workerId = pool.findIndex((slot) => slot === undefined) + 1;
    pool[workerId - 1] = (async () => {
        const slug = path.split('/').pop() ?? '';
        const itemType = type === 'plugins' ? 'plugin' : 'theme';
        try {
            const errorLogPath = join(path, 'unit-tests', 'error.log');
            const hostLogDirectory = dirname(errorLogPath);
            if (!existsSync(hostLogDirectory)) {
                mkdirSync(hostLogDirectory, { recursive: true });
            }
            // Ensure the log file exists and is empty
            writeFileSync(errorLogPath, '');

            const env: Record<string, string> = {
              ITEM_SLUG: slug,
              ITEM_TYPE: itemType,
              LOG_FILE: errorLogPath,
              PLAYGROUND_PORT: (9400 + workerId).toString()
            };
            return startVitest('test', vitestFilter, {
                ...vitestBaseOptions,
                watch: false,
                reporters: ['verbose'], //['json'],
                outputFile: join(path, 'unit-tests', 'results.json'),
                env,
            }).then((result) => {
                const output = formatTestResult(result, slug);
                console.log(output);
                return result;
            });
        } catch (err) {
            console.error(`Failed to run tests for ${itemType} ${slug}:`, err.message);
        }
    })().finally(() => {
        pool[workerId - 1] = undefined;
    });
}

// Wait for all workers to finish.
await Promise.all(pool);

// Save data.
if (!dryRun) {
    await exec(
        `. ./scripts/save-data.sh && save_data --add . --message "✅ tested a batch of ${limit} ${type}" --push`,
        { cwd: rootDir, shell: 'bash' }
    );
}
