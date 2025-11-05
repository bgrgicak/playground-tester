/**
 * Test Runner - Executes vitest for a single item
 *
 * This file runs in a spawned process with specific Node.js flags that
 * determine the WASM mode (JSPI vs Asyncify):
 * - With --experimental-wasm-jspi: JSPI mode
 * - Without: Asyncify mode
 *
 * The mode is automatically detected at runtime via wasm-feature-detect.
 */

import { join, dirname } from 'path';
import yargs from 'yargs';
import { startVitest, parseCLI } from 'vitest/node';
import type { Vitest } from 'vitest/node';
import { existsSync, mkdirSync, writeFileSync } from 'fs';
import { parseTestLogs } from './lib/log-parser.ts';
import { jspi } from 'wasm-feature-detect';

function formatTestResult(result: Vitest, slug: string, mode: string): string {
    const files = result.state.getFiles();

    // Check if all tests passed
    const allPassed = files.every(file => file.result?.state === 'pass');

    if (allPassed) {
        return `✅ ${slug} (${mode}) passed`;
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
    let output = `❌ ${slug} (${mode}) (${failedCount} failed, ${passedTests} passed)`;
    for (const test of failedTests) {
        output += `\n  • ${test.name} - ${test.error}`;
    }

    return output;
}

// Parse command line arguments
const argv = yargs(process.argv.slice(2))
    .option('item-path', {
        type: 'string',
        description: 'Path to the item to test',
        demandOption: true,
    })
    .option('slug', {
        type: 'string',
        description: 'Item slug',
        demandOption: true,
    })
    .option('item-type', {
        type: 'string',
        description: 'Item type (plugin or theme)',
        demandOption: true,
    })
    .option('worker-id', {
        type: 'number',
        description: 'Worker ID for port assignment',
        demandOption: true,
    })
    .option('type', {
        type: 'string',
        description: 'Type (plugins or themes)',
        demandOption: true,
        choices: ['plugins', 'themes'],
    })
    .help()
    .parseSync();

const itemPath = argv['item-path'];
const slug = argv.slug;
const itemType = argv['item-type'];
const workerId = argv['worker-id'];
const type = argv.type;

// Detect the WASM mode based on runtime capabilities
const detectedJspi = await jspi();
const mode = detectedJspi ? 'jspi' : 'asyncify';

// Verify expected mode matches detected mode (for debugging)
if (process.env.WASM_MODE && process.env.WASM_MODE !== mode) {
    console.warn(`[${slug}] Warning: Expected ${process.env.WASM_MODE} but detected ${mode}`);
}

// Setup test directory for this mode (asyncify/ or jspi/)
const testDirectory = join(itemPath, mode);
const errorLogPath = join(testDirectory, 'error.log');

if (!existsSync(testDirectory)) {
    mkdirSync(testDirectory, { recursive: true });
}

// Initialize empty log file
writeFileSync(errorLogPath, '');

// Configure environment for vitest
const env: Record<string, string> = {
    ITEM_SLUG: slug,
    ITEM_TYPE: itemType,
    LOG_FILE: errorLogPath,
    PLAYGROUND_PORT: (9400 + workerId).toString()
};

// Parse vitest CLI options
const { filter: vitestFilter, options: vitestBaseOptions } = parseCLI(['vitest', 'run']);

// Suppress all vitest output by intercepting stdout/stderr
const originalStdoutWrite = process.stdout.write.bind(process.stdout);
const originalStderrWrite = process.stderr.write.bind(process.stderr);
process.stdout.write = (): boolean => true;
process.stderr.write = (): boolean => true;

// Run vitest silently
try {
    const result = await startVitest('test', vitestFilter, {
        ...vitestBaseOptions,
        watch: false,
        reporters: [],
        env,
    });

    // Restore stdout/stderr immediately after vitest completes
    process.stdout.write = originalStdoutWrite;
    process.stderr.write = originalStderrWrite;

    if (!result) {
        console.error(`[${slug}] Failed to start vitest`);
        process.exit(1);
    }

    // Manually write JSON results file (avoids vitest's "JSON report written" message)
    // Format matches what parseTestLogs expects
    const testFiles = result.state.getFiles();
    const resultData = {
        success: testFiles.every(file => file.result?.state === 'pass'),
        testResults: testFiles.map(file => ({
            name: file.name,
            status: file.result?.state,
            assertionResults: file.tasks.map(task => ({
                ancestorTitles: task.suite ? [task.suite.name] : [],
                fullName: task.name,
                status: task.result?.state || 'pending',
                title: task.name,
                failureMessages: task.result?.errors?.map(e => e.message) || [],
                meta: task.meta
            }))
        }))
    };
    writeFileSync(join(testDirectory, 'results.json'), JSON.stringify(resultData, null, 2));

    // Format and display test results
    const output = formatTestResult(result, slug, mode);
    console.log(output);

    // Parse error logs and generate error.json
    try {
        const firstLetter = slug.charAt(0);
        const logFilePath = `/logs/${type}/${firstLetter}/${slug}/error.json`;

        // Parse test logs
        const errors = parseTestLogs(
            testDirectory,
            mode, // Use mode as test name instead of 'unit-tests'
            itemType as 'plugin' | 'theme',
            slug,
            logFilePath
        );

        // Write error.json for this mode
        const testErrorJsonPath = join(testDirectory, 'error.json');
        writeFileSync(testErrorJsonPath, JSON.stringify(errors, null, 2));
    } catch (err: any) {
        console.error(`[${slug}] Failed to parse logs:`, err.message);
    }

    // Determine exit code based on test results
    const files = result.state.getFiles();
    const allPassed = files.every(file => file.result?.state === 'pass');

    // Exit with appropriate code
    process.exit(allPassed ? 0 : 1);

} catch (err: any) {
    // Restore stdout/stderr in case of error
    process.stdout.write = originalStdoutWrite;
    process.stderr.write = originalStderrWrite;
    console.error(`[${slug}] Failed to run tests:`, err.message);
    process.exit(1);
}
