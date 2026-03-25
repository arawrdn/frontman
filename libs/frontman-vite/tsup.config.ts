import { defineConfig } from 'tsup';
import { readFileSync } from 'fs';

const pkg = JSON.parse(readFileSync('./package.json', 'utf-8'));

const nodeBuiltins = [
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
  'node:fs',
  'node:path',
  'node:os',
  'node:child_process',
  'node:crypto',
  'node:util',
  'node:stream',
  'node:events',
  'node:buffer',
  'node:url',
  'node:http',
  'node:https',
  'node:module',
];

const externalDeps = [
  // Workspace dependencies (resolved at runtime via frontman-core)
  '@frontman-ai/frontman-core',
  '@frontman-ai/frontman-protocol',
  '@frontman/bindings',
  '@rescript/runtime',
  'sury',
  'dom-element-to-component-source',
  // Peer / optional dependencies
  'vite',
  'lighthouse',
  'chrome-launcher',
  ...nodeBuiltins,
];

export default defineConfig([
  // Main entry point
  {
    entry: { 'index': './src/FrontmanVite.res.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: true,
    dts: true,
    noExternal: [/vite-plugin-vue-source/],
    external: externalDeps,
    platform: 'node',
    target: 'node18',
    treeshake: true,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
  },
  // CLI entry point
  {
    entry: { 'cli': './src/cli/cli.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: false,
    external: externalDeps,
    platform: 'node',
    target: 'node18',
    treeshake: true,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    banner: {
      js: '#!/usr/bin/env node',
    },
  },
]);
