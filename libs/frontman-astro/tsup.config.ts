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
  'astro',
  'astro/toolbar',
  'astro/config',
  'lighthouse',
  'chrome-launcher',
  // Node.js built-ins
  'node:module',
  'fs',
  'path',
  'os',
  'child_process',
  'crypto',
  'util',
  'stream',
  'stream/web',
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
  // Main library entry point
  {
    entry: { 'index': './index.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: true,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    external: sharedExternal,
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
  // Integration entry point
  {
    entry: { 'integration': './src/FrontmanAstro__Integration.res.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: false,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    external: sharedExternal,
    platform: 'node',
    target: 'node18',
    treeshake: true,
  },
  // Toolbar entry point (runs in browser — workspace deps must be bundled, not externalized)
  {
    entry: { 'toolbar': './src/FrontmanAstro__ToolbarApp.res.mjs' },
    format: ['esm'],
    outDir: 'dist',
    clean: false,
    define: { '__PACKAGE_VERSION__': JSON.stringify(pkg.version) },
    external: ['astro', 'astro/toolbar'],
    platform: 'browser',
    target: 'es2020',
    treeshake: true,
  },
]);
