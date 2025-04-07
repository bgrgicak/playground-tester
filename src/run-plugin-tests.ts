/**
 * Run all plugin tests from "wp-public-data" using the Playground Tester.
 * Use up to MAX_CONCURRENCY workers to execute the tests concurrently.
 */
import { exec as execCallback } from 'child_process';
import { existsSync, readdirSync } from 'fs';
import { join } from 'path';
import { promisify } from 'util';

const exec = promisify(execCallback);

const rootDir = join(import.meta.dirname, '..');
const MAX_CONCURRENCY = 8;

// Get all plugin slugs.
const pluginsDir = join(rootDir, 'wp-public-data', 'plugins');
const plugins: string[] = [];
for (const pluginFile of readdirSync(pluginsDir)) {
    if (pluginFile.endsWith('.json')) {
        plugins.push(pluginFile.substring(0, pluginFile.length - '.json'.length));
    };
}

// Run tests for all plugins.
const pool = new Array(MAX_CONCURRENCY).fill(undefined);

for (const plugin of plugins) {
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

            const pluginPath = join(rootDir, 'data', 'logs', 'plugins', plugin[0], plugin);
            const output = await exec(
                `./scripts/run-tests.sh --plugin ${pluginPath} --wordpress ${wordpressPath} || true`,
                {
                    cwd: rootDir,
                    env: { ...process.env, PLAYGROUND_PORT: (9400 + workerId).toString() },
                }
            );
            console.log(output.stdout);
        } catch (err) {
            console.error(`Failed to run tests for ${plugin}:`, err.message);
        }
    })().finally(() => {
        pool[workerId - 1] = undefined;
    });
}

await Promise.all(pool);
