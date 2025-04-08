/**
 * Download all plugins listed in "wp-public-data" from WordPress.org.
 * Use up to MAX_CONCURRENCY workers to download the plugins concurrently.
 */
import { createWriteStream, readdirSync } from 'fs';
import { mkdir } from 'fs/promises';
import { join } from 'path';
import { Readable } from 'stream';
import { ReadableStream } from 'stream/web';

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

// Download all plugins.
const pool = new Set<Promise<void>>();
const downloadsDir = join(rootDir, 'temp', 'downloads');
await mkdir(downloadsDir, { recursive: true });

for (const plugin of plugins) {
    if (pool.size >= MAX_CONCURRENCY) {
        await Promise.race(pool);
    }

    const promise = (async () => {
        try {
            const url = `https://downloads.wordpress.org/plugin/${plugin}.latest-stable.zip`;
            const response = await fetch(url);
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }
            if (!response.body) {
                throw new Error('No response body');
            }
            const writeStream = createWriteStream(join(downloadsDir, `${plugin}.zip`));
            await Readable.fromWeb(response.body as ReadableStream).pipe(writeStream);
            console.log(`Downloaded ${plugin}`);
        } catch (err) {
            console.error(`Failed to download ${plugin}:`, err.message);
        }
    })().finally(() => {
        pool.delete(promise);
    });
    pool.add(promise);
}

await Promise.all(pool);
