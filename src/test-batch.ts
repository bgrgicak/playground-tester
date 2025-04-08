/**
 * Run all plugin tests from "wp-public-data" using the Playground Tester.
 * Use up to MAX_CONCURRENCY workers to execute the tests concurrently.
 */
import { exec as execCallback } from 'child_process';
import { existsSync, readdirSync } from 'fs';
import { join } from 'path';
import { promisify } from 'util';
import yargs from 'yargs';

const exec = promisify(execCallback);

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

// Get plugins/themes to test.
const findResult = await exec(
    `. ./scripts/lib/log-parser/analyze-json-logs.sh && get_first_n_logs_to_test "${type}" "${limit}" --prefix-chars "${prefixChars}"`,
    {
        cwd: rootDir,
        maxBuffer: 100 * 1024 * 1024,
    }
);
const paths = findResult.stdout.split('\n').filter(Boolean);

// Update all items in the current batch to prevent them from being picked up by another runner.
// We will only replace the TIMESTAMP-last-tested.txt file to indicate that the item is being processed.
for (const path of paths) {
    await exec(`rm ${path}/*-last-tested.txt 2>/dev/null || true`);
    await exec(`echo "Last tested on \$(date +%Y-%m-%d\\ %H:%M:%S)" > "${path}/$(date +%Y%m%d-%H%M%S)-last-tested.txt"`);
}
await exec(
    `. ./scripts/save-data.sh && save_data --add . --message "testing a batch of ${limit} ${type}" --push`,
    { cwd: rootDir, shell: 'bash' }
);

// Run tests for plugins/themes batch.
const pool = new Array(MAX_CONCURRENCY).fill(undefined);
for (const path of paths) {
    const workers = pool.filter((slot) => slot !== undefined);
    if (workers.length >= pool.length) {
        await Promise.race(workers);
    }

    const workerId = pool.findIndex((slot) => slot === undefined) + 1;
    pool[workerId - 1] = (async () => {
        try {
            const workerWordpressPath = join(rootDir, 'temp', `worker-${workerId}`);
            const wordpressPath = join(workerWordpressPath, 'wordpress');

            // Reset WordPress installation if it exists, prepare it otherwise.
            if (existsSync(join(wordpressPath, '.git'))) {
                await exec('git reset --hard', { cwd: wordpressPath });
            } else {
                await exec(
                    `./scripts/build-wordpress.sh --output ${workerWordpressPath}`,
                    {
                        cwd: rootDir,
                        env: { ...process.env, PLAYGROUND_PORT: (9400 + workerId).toString() },
                    }
                );
            }

            // Run tests.
            const itemType = type === 'plugins' ? 'plugin' : 'theme';
            const output = await exec(
                `./scripts/run-tests.sh --${itemType} ${path} --wordpress ${wordpressPath} || true`,
                {
                    cwd: rootDir,
                    env: { ...process.env, PLAYGROUND_PORT: (9400 + workerId).toString() },
                }
            );

            console.log(output.stdout);
        } catch (err) {
            console.error(`Failed to run tests for ${path.split('/').pop()}:`, err.message);
        }
    })().finally(() => {
        pool[workerId - 1] = undefined;
    });
}

// Wait for all workers to finish.
await Promise.all(pool.filter((slot) => slot !== undefined));

// Save data.
await exec(
    `. ./scripts/save-data.sh && save_data --add . --message "tested a batch of ${limit} ${type}" --push`,
    { cwd: rootDir, shell: 'bash' }
);
