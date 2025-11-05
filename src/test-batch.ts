/**
 * Batch Test Orchestrator
 *
 * Runs all plugin/theme tests using the Playground Tester with up to
 * MAX_CONCURRENCY workers executing tests concurrently.
 *
 * For each item, tests are run in both WASM modes sequentially:
 * 1. Asyncify mode (default Node.js)
 * 2. JSPI mode (with --experimental-wasm-jspi flag)
 *
 * Results from both modes are aggregated into a single error.json per item.
 */
import { exec as execCallback, spawn } from 'child_process';
import { join, resolve } from 'path';
import { promisify } from 'util';
import yargs from 'yargs';
import { existsSync, writeFileSync, readFileSync, rmSync } from 'fs';
import type { ErrorEntry } from './lib/log-parser.ts';

const exec = promisify(execCallback);

/**
 * Run tests for a single item in a specific WASM mode by spawning test-runner.ts
 * with appropriate Node.js flags.
 */
async function runTestsForMode(
    itemPath: string,
    slug: string,
    itemType: string,
    mode: 'asyncify' | 'jspi',
    workerId: number,
    type: string
): Promise<{ success: boolean; exitCode: number }> {
    return new Promise((resolve) => {
        const testRunnerPath = join(import.meta.dirname, 'test-runner.ts');

        // Determine Node.js flags based on mode
        const nodeFlags = [
            '--experimental-strip-types',
            '--disable-warning=ExperimentalWarning',
        ];

        if (mode === 'jspi') {
            // Add JSPI-specific flags
            nodeFlags.push('--experimental-wasm-jspi');
            nodeFlags.push('--no-warnings');
        }

        const args = [
            ...nodeFlags,
            testRunnerPath,
            `--item-path=${itemPath}`,
            `--slug=${slug}`,
            `--item-type=${itemType}`,
            `--worker-id=${workerId}`,
            `--type=${type}`,
        ];

        const child = spawn('node', args, {
            stdio: 'inherit',
            env: {
                ...process.env,
                WASM_MODE: mode,
            },
        });

        child.on('exit', (code) => {
            resolve({
                success: code === 0,
                exitCode: code || 0
            });
        });

        child.on('error', (err) => {
            console.error(`[${slug}] Failed to spawn test runner for ${mode}:`, err);
            resolve({ success: false, exitCode: 1 });
        });
    });
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
const limit = argv['item-path'] ? 1 : argv.limit;
const prefixChars = argv['prefix-chars'];
const dryRun = !!argv['dry-run'];
const itemPath = argv['item-path'];

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

if (paths.length === 0) {
    console.error('No items to test');
    process.exit(1);
} else if (paths.length === 1) {
    console.log(`Testing ${paths[0].split('/').pop() ?? ''}`);
} else {
    console.log(`Testing ${type} ${paths.length} items`);
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
            // Clean up old test directories before running new tests
            // Note: *-boot directories are from legacy testing approach, can be removed in future
            const oldDirs = ['unit-tests', 'asyncify', 'jspi', 'ast-sqlite-boot', 'jspi-boot', 'asyncify-boot'];
            for (const dir of oldDirs) {
                const dirPath = join(path, dir);
                if (existsSync(dirPath)) {
                    rmSync(dirPath, { recursive: true, force: true });
                }
            }

            // Run Asyncify tests
            const asyncifyResult = await runTestsForMode(
                path,
                slug,
                itemType,
                'asyncify',
                workerId,
                type
            );

            // Run JSPI tests
            const jspiResult = await runTestsForMode(
                path,
                slug,
                itemType,
                'jspi',
                workerId,
                type
            );

            // Aggregate results from both modes
            const itemErrorJsonPath = join(path, 'error.json');
            let allErrors: ErrorEntry[] = [];

            // Read existing errors if file exists (for other test types)
            if (existsSync(itemErrorJsonPath)) {
                try {
                    const existingContent = readFileSync(itemErrorJsonPath, 'utf-8');
                    const existingErrors = JSON.parse(existingContent) as ErrorEntry[];
                    // Filter out old asyncify/jspi/unit-tests errors
                    allErrors = existingErrors.filter(e =>
                        e.test !== 'asyncify' &&
                        e.test !== 'jspi' &&
                        e.test !== 'unit-tests'
                    );
                } catch (e) {
                    console.error(`[${slug}] Failed to parse existing error.json:`, e);
                }
            }

            // Add errors from asyncify mode
            const asyncifyErrorPath = join(path, 'asyncify', 'error.json');
            if (existsSync(asyncifyErrorPath)) {
                try {
                    const asyncifyErrors = JSON.parse(readFileSync(asyncifyErrorPath, 'utf-8')) as ErrorEntry[];
                    allErrors.push(...asyncifyErrors);
                } catch (e) {
                    console.error(`[${slug}] Failed to read asyncify error.json:`, e);
                }
            }

            // Add errors from jspi mode
            const jspiErrorPath = join(path, 'jspi', 'error.json');
            if (existsSync(jspiErrorPath)) {
                try {
                    const jspiErrors = JSON.parse(readFileSync(jspiErrorPath, 'utf-8')) as ErrorEntry[];
                    allErrors.push(...jspiErrors);
                } catch (e) {
                    console.error(`[${slug}] Failed to read jspi error.json:`, e);
                }
            }

            // Write aggregated error.json
            writeFileSync(itemErrorJsonPath, JSON.stringify(allErrors, null, 2));
        } catch (err: any) {
            console.error(`[${slug}] Failed to run tests:`, err.message);
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
