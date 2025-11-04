import { defineConfig } from 'vitest/config';

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
    outputFile: 'temp/test-results',
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

