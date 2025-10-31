import { defineConfig } from 'vitest/config';
import { JsonReporter } from 'vitest/reporters';
import yargs from 'yargs';

const forwardedIndex = process.argv.indexOf('--');

if (forwardedIndex >= 0) {
  const forwarded = process.argv.slice(forwardedIndex + 1);
  if (forwarded.length > 0) {
    const parsed = yargs(forwarded)
      .option('plugin', {
        type: 'string',
        describe: 'Name of the plugin to test',
      })
      .option('theme', {
        type: 'string',
        describe: 'Name of the theme to test',
      })
      .parseSync() as { plugin?: string; theme?: string };

    if (parsed.plugin) {
      process.env.WP_TEST_PLUGIN = parsed.plugin;
    }

    if (parsed.theme) {
      process.env.WP_TEST_THEME = parsed.theme;
    }
  }
}

class PlaygroundJsonReporter extends JsonReporter {
  constructor(options: ConstructorParameters<typeof JsonReporter>[0] = {}) {
    super(options);
  }

  async writeReport(report: string) {
    let enhancedReport = report;

    try {
      const data = JSON.parse(report) as Record<string, unknown>;
      data.test = true;
      enhancedReport = JSON.stringify(data);
    } catch (error) {
      const message = error instanceof Error ? error.message : String(error);
      this.ctx?.logger.warn?.(`Failed to extend Vitest JSON report: ${message}`);
    }

    await super.writeReport(enhancedReport);
  }
}

export default defineConfig({
  test: {
    globals: true,
    include: ['src/test/**/*.spec.ts'],
    testTimeout: 120000, // 2 minutes
    hookTimeout: 120000, // 2 minutes
    exclude: [
      '**/node_modules/**',
      '**/dist/**',
      '**/data/**',
      '**/temp/**',
      '**/wordpress-develop/**',
      '**/wp-public-data/**',
      '**/logs/**',
    ],
    reporters: [
      'default',
      new PlaygroundJsonReporter({ outputFile: 'test-results/vitest-report.json' }),
    ],
  },
  esbuild: {
    target: 'node23',
  },
  server: {
    watch: {
      ignored: [
        '**/node_modules/**',
        '**/dist/**',
        '**/data/**',
        '**/temp/**',
        '**/wordpress-develop/**',
        '**/wp-public-data/**',
        '**/logs/**',
      ],
    },
  },
});

