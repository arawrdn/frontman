import { defineConfig } from 'tsup';
import { readFileSync } from 'fs';

const pkg = JSON.parse(readFileSync('./package.json', 'utf-8'));

const sharedExternal = [
  // Workspace dependencies (resolved at runtime via frontman-core)
  '@frontman-ai/frontman-core',
  '@frontman-ai/frontman-protocol',
  '@frontman/bindings',
  '@rescript/runtime',
  'sury',
  'dom-element-to-component-source',
  // Peer / optional dependencies
  '@sentry/nextjs',
  '@opentelemetry/api',
  '@opentelemetry/sdk-logs',
  '@opentelemetry/sdk-trace-base',
  '@opentelemetry/sdk-node',
  'next',
  'next/server',
  'react',
  'react-dom',
  'lighthouse',
  'chrome-launcher',
  // Node.js built-ins
  'fs',
  'path',
  'os',
  'child_process',
  'crypto',
  'util',
  'stream',
  'events',
  'buffer',
  'url',
  'http',
  'https',
  'net',
  'tls',
  'zlib',
  'readline',
  'tty',
  'assert',
  'process',
];

export default defineConfig([
  // Main entry point
  {
    entry: { 'index': './src/FrontmanNextjs.res.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: true,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    external: sharedExternal,
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
  // Instrumentation entry point
  {
    entry: { 'instrumentation': './src/FrontmanNextjs__Instrumentation.res.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: false, // Don't clean, we already did in first build
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    external: sharedExternal,
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
  // CLI entry point
  {
    entry: { 'cli': './src/cli/cli.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: false,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    external: sharedExternal,
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
]);
