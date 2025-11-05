import { describe, it, expect, afterAll, beforeAll } from 'vitest';
import { runCLI } from '@wp-playground/cli';
import type { RunCLIServer } from '@wp-playground/cli';
import { type Blueprint } from '@wp-playground/blueprints';
import type { PHPRequest, PHPResponse } from '@php-wasm/universal';
import { phpVar } from '@php-wasm/util';
import { errorLogPath as vfsErrorLogPath } from '@php-wasm/logger';
import path from 'path';
import { writeFileSync } from 'fs';

interface Env {
    ITEM_TYPE?: string;
    ITEM_SLUG?: string;
    LOG_FILE?: string;
    PLAYGROUND_PORT?: string;
}

const env = process.env as Env;

// write env vars to a temp file
writeFileSync(path.resolve(process.cwd(), 'temp', 'env.json'), JSON.stringify(env, null, 2));

// write process.env to a temp file
writeFileSync(path.resolve(process.cwd(), 'temp', 'process.env.json'), JSON.stringify(process.env, null, 2));

interface TestArgs {
    plugin?: string;
    theme?: string;
    hostErrorLogPath: string;
    playgroundPort?: number;
}

const args: TestArgs = {
    hostErrorLogPath: path.resolve(process.cwd(), 'temp', 'error.log'),
};
if (env.ITEM_TYPE === 'theme') {
    args.theme = env.ITEM_SLUG;
} else if (env.ITEM_TYPE === 'plugin') {
    args.plugin = env.ITEM_SLUG;
}
if (env.LOG_FILE) {
    args.hostErrorLogPath = env.LOG_FILE;
}
if (env.PLAYGROUND_PORT) {
    args.playgroundPort = parseInt(env.PLAYGROUND_PORT);
}

function getBlueprint(args: TestArgs) : Blueprint {
    const blueprint: Blueprint = {
        extraLibraries: [ 'wp-cli' ],
        steps: [
            {
                step: 'login',
                username: 'admin',
            }
        ],
    };
    if (args.plugin) {
        blueprint.steps.push({
            "step": "installPlugin",
            "pluginData": {
                "resource": "wordpress.org/plugins",
                "slug": args.plugin,
            },
            "options": {
                "activate": true
            }
        });
    }
    if (args.theme) {
        blueprint.steps.push({
            "step": "installTheme",
            "themeData": {
                "resource": "wordpress.org/themes",
                "slug": args.theme
            },
            "options": {
                "activate": true,
                "importStarterContent": true
            }
        });
    }

    return blueprint;
}

const requestFollowRedirects = async (playground: RunCLIServer['playground'], request: PHPRequest) : Promise<PHPResponse> => {
    const response = await playground.request(request);
    if (response.httpStatusCode >= 300 && response.httpStatusCode < 400 && response.headers.location) {
        return requestFollowRedirects(playground, {
            url: response.headers.location[0],
        });
    }
    return response;
}

describe('Unit tests', () => {
    let cli: RunCLIServer;
    let server: RunCLIServer['server'];
    let playground: RunCLIServer['playground'];
    let documentRoot: string;
    let absoluteUrl: string;
    let bootError: Error | undefined;
    beforeAll(async () => {
        try {
            cli = await runCLI({
                command: 'server',
                blueprint: getBlueprint(args),
                quiet: true,
                mount: [
                    {
                        hostPath: args.hostErrorLogPath,
                        vfsPath: vfsErrorLogPath,
                    }
                ],
                internalCookieStore: true,
                port: args.playgroundPort,
            });
            server = cli.server;
            playground = cli.playground;
            documentRoot = await playground.documentRoot;
            absoluteUrl = await playground.absoluteUrl;
        } catch (error) {
            bootError = error as Error;
        }
    });
    afterAll(async () => {
        if (server) {
            await server.close();
        }
    });

    describe('boot', () => {
        it('should boot without errors', ({ task }) => {
            if (bootError) {
                task.meta['error'] = {
                    message: bootError?.message,
                    stack: bootError?.stack,
                    cause: bootError?.cause,
                };
            }
            expect(bootError).toBeUndefined();
        });
    });

    describe.skipIf(bootError)('wordpress', () => {
        it('create a post', async () => {
            const postTitle = 'Test Post Title';
            const postContent = 'This is a test post content';
            const result = await playground.run({
                code: `<?php
                require_once "${documentRoot}/wp-load.php";
                $post_id = wp_insert_post([
                    'post_title' => ${phpVar(postTitle)},
                    'post_content' => ${phpVar(postContent)},
                ]);
                $post = get_post($post_id);
                echo json_encode($post);
                ?>`
            });

            const post = result.json;
            expect(post.post_title).toBe(postTitle);
            expect(post.post_content).toBe(postContent);
        });
        it('should load wp-admin', async () => {
            const response = await requestFollowRedirects(
                playground,
                {
                    url: '/wp-admin/',
                    method: 'GET'
                }
            );
            expect(response.httpStatusCode).toBe(200);
            expect(response.text).toContain('<h1>Dashboard</h1>');
        });
    });

    describe.skipIf(!args.plugin || bootError)('plugin', () => {
        it('should be active', async () => {
            const r = await playground.cli([
                'php',
                '/tmp/wp-cli.phar',
                `--path=${documentRoot}`,
                'plugin',
                'list',
                '--status=active',
                '--field=name',
                '--format=json'
            ]);
            expect(JSON.parse(await r.stdoutText)).toContain(args.plugin);
        });
    });

    describe.skipIf(!args.theme || bootError)('theme', () => {
        it('should be active', async () => {
            const r = await playground.cli([
                'php',
                '/tmp/wp-cli.phar',
                `--path=${documentRoot}`,
                'theme',
                'list',
                '--status=active',
                    '--field=name',
                    '--format=json'
            ]);
            expect(JSON.parse(await r.stdoutText)).toMatchObject([args.theme]);
        });
    });
});

