/**
 * Log parser for Playground Tester error logs and test results.
 * Parses error.log files and results.json files to generate error.json reports.
 */
import { readFileSync, existsSync } from 'fs';

export interface ErrorEntry {
    message: string;
    level: 'FATAL' | 'WARNING' | 'PARSE' | 'NOTICE' | 'DEPRECATED' | 'STRICT' | 'RECOVERABLE_FATAL' | 'INFO';
    type: 'PHP' | 'SQL' | 'PLAYGROUND' | 'OTHER';
    test: string;
    plugin?: string;
    theme?: string;
    details: string;
    log: string;
}

export interface TestResultsMeta {
    error?: {
        message: string;
        stack: string;
    };
}

export interface AssertionResult {
    ancestorTitles: string[];
    fullName: string;
    status: string;
    title: string;
    failureMessages?: string[];
    meta?: TestResultsMeta;
}

export interface TestResult {
    assertionResults: AssertionResult[];
    status: string;
    name: string;
}

export interface TestResults {
    success: boolean;
    testResults: TestResult[];
}

/**
 * Preprocesses error log content by removing CLI output artifacts
 */
function prepareLogContent(content: string): string {
    let processed = content;

    // Remove "Node.js v..." lines
    processed = processed.replace(/^Node\.js v.*/gm, '');

    // Remove "Error: " prefix before PHP error timestamps
    processed = processed.replace(
        /^Error: (\[\d{2}-[A-Za-z]{3}-\d{4} \d{2}:\d{2}:\d{2} UTC\])/gm,
        '$1'
    );

    return processed;
}

/**
 * Parses an error.log file and extracts structured error entries
 */
export function parseErrorLog(
    logPath: string,
    testName: string,
    itemType: 'plugin' | 'theme',
    itemName: string,
    logFilePath: string
): ErrorEntry[] {
    if (!existsSync(logPath)) {
        return [];
    }

    const content = readFileSync(logPath, 'utf-8');
    const prepared = prepareLogContent(content);

    // Check if file is empty or contains only whitespace
    if (!prepared.trim()) {
        return [];
    }

    const lines = prepared.split('\n');
    const errors: ErrorEntry[] = [];
    let currentError: ErrorEntry | null = null;

    for (const line of lines) {
        // Check if this line starts a new error
        const timestampMatch = line.match(/^\[(\d{2}-[A-Za-z]{3}-\d{4} \d{2}:\d{2}:\d{2} UTC)\]/);
        const playgroundMatch = line.match(/^file:\/\/\/.*\.js:\d+/);

        if (timestampMatch) {
            // Save previous error if exists
            if (currentError && currentError.details) {
                errors.push(currentError);
            }

            // Determine error level and type
            let level: ErrorEntry['level'] = 'INFO';
            let type: ErrorEntry['type'] = 'OTHER';

            if (line.includes('PHP Fatal error')) {
                level = 'FATAL';
                type = 'PHP';
            } else if (line.includes('PHP Warning')) {
                level = 'WARNING';
                type = 'PHP';
            } else if (line.includes('PHP Parse error')) {
                level = 'PARSE';
                type = 'PHP';
            } else if (line.includes('PHP Notice')) {
                level = 'NOTICE';
                type = 'PHP';
            } else if (line.includes('PHP Deprecated')) {
                level = 'DEPRECATED';
                type = 'PHP';
            } else if (line.includes('PHP Strict Standards')) {
                level = 'STRICT';
                type = 'PHP';
            } else if (line.includes('PHP Recoverable fatal error')) {
                level = 'RECOVERABLE_FATAL';
                type = 'PHP';
            } else if (line.includes('WordPress database')) {
                level = 'FATAL';
                type = 'SQL';
            }

            // Start new error
            currentError = {
                message: '',
                level,
                type,
                test: testName,
                details: line,
                log: logFilePath
            };

            // Set plugin or theme field
            if (itemType === 'plugin') {
                currentError.plugin = itemName;
            } else {
                currentError.theme = itemName;
            }

        } else if (playgroundMatch) {
            // Save previous error if exists
            if (currentError && currentError.details) {
                errors.push(currentError);
            }

            // Create Playground error
            currentError = {
                message: '',
                level: 'FATAL',
                type: 'PLAYGROUND',
                test: testName,
                details: line,
                log: logPath
            };

            // Set plugin or theme field
            if (itemType === 'plugin') {
                currentError.plugin = itemName;
            } else {
                currentError.theme = itemName;
            }

        } else if (currentError && line.trim()) {
            // Append to current error details
            currentError.details += '\n' + line;
        }
    }

    // Save last error if exists
    if (currentError && currentError.details) {
        errors.push(currentError);
    }

    // Extract messages from details
    for (const error of errors) {
        if (error.type === 'SQL') {
            // Extract SQL error message
            const messageMatch = error.details.match(/Error message was: ([^\n]+)/);
            if (messageMatch) {
                error.message = messageMatch[1].replace(/<[^>]*>/g, '').split('\n\nBacktrace:')[0];
            } else {
                // Try to extract from SQLSTATE error
                const sqlStateMatch = error.details.match(/SQLSTATE\[.*?\]: (.+?)(?:\n|$)/);
                if (sqlStateMatch) {
                    error.message = sqlStateMatch[1].trim();
                } else {
                    error.message = error.details;
                }
            }
        } else if (error.type === 'PHP') {
            // Extract PHP error message (first line after the error type)
            const match = error.details.match(/PHP [^:]+:\s*(.+?)(?:\n|$)/);
            if (match) {
                error.message = match[1].trim();
            } else {
                error.message = error.details.split('\n')[0];
            }
        } else if (error.type === 'PLAYGROUND') {
            error.message = error.details;
        } else {
            error.message = error.details;
        }
    }

    return errors;
}

/**
 * Parses a results.json file and extracts errors from test failures with meta.error
 */
export function parseResultsJson(
    resultsPath: string,
    testName: string,
    itemType: 'plugin' | 'theme',
    itemName: string,
    logFilePath: string
): ErrorEntry[] {
    if (!existsSync(resultsPath)) {
        return [];
    }

    const content = readFileSync(resultsPath, 'utf-8');
    let results: TestResults;

    try {
        results = JSON.parse(content);
    } catch (e) {
        console.error(`Failed to parse results.json at ${resultsPath}:`, e);
        return [];
    }

    const errors: ErrorEntry[] = [];

    for (const testResult of results.testResults) {
        for (const assertion of testResult.assertionResults) {
            // Only extract errors from failed tests with meta.error
            if (assertion.status === 'failed' && assertion.meta?.error) {
                const error: ErrorEntry = {
                    message: assertion.meta.error.message,
                    level: 'FATAL',
                    type: 'PLAYGROUND',
                    test: testName,
                    details: assertion.meta.error.stack || assertion.meta.error.message,
                    log: logFilePath
                };

                // Set plugin or theme field
                if (itemType === 'plugin') {
                    error.plugin = itemName;
                } else {
                    error.theme = itemName;
                }

                errors.push(error);
            }
        }
    }

    return errors;
}

/**
 * Merges and deduplicates error arrays
 */
export function mergeErrors(errors: ErrorEntry[]): ErrorEntry[] {
    // Simple deduplication based on message + test + type
    const seen = new Set<string>();
    const unique: ErrorEntry[] = [];

    for (const error of errors) {
        const key = `${error.test}:${error.type}:${error.message}`;
        if (!seen.has(key)) {
            seen.add(key);
            unique.push(error);
        }
    }

    return unique;
}

/**
 * Parses logs for a test and generates error entries
 */
export function parseTestLogs(
    testDirectory: string,
    testName: string,
    itemType: 'plugin' | 'theme',
    itemName: string,
    logFilePath: string
): ErrorEntry[] {
    const errorLogPath = `${testDirectory}/error.log`;
    const resultsJsonPath = `${testDirectory}/results.json`;

    const errorLogErrors = parseErrorLog(errorLogPath, testName, itemType, itemName, logFilePath);
    const resultsJsonErrors = parseResultsJson(resultsJsonPath, testName, itemType, itemName, logFilePath);

    const allErrors = [...errorLogErrors, ...resultsJsonErrors];
    return mergeErrors(allErrors);
}
