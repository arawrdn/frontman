import { defineConfig } from 'tsup';

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

const internalDeps = [
  '@frontman/frontman-core',
  '@frontman/frontman-protocol',
  '@frontman/bindings',
  '@rescript/runtime',
  'sury',
  'dom-element-to-component-source',
];

export default defineConfig([
  // Service plugin (Node.js, CJS — Vue CLI uses require())
  {
    entry: { 'service': './src/FrontmanVueCli.res.mjs' },
    format: ['cjs'],
    outDir: 'dist',
    clean: true,
    dts: true,
    noExternal: internalDeps,
    external: ['webpack', 'lighthouse', 'chrome-launcher', ...nodeBuiltins],
    platform: 'node',
    target: 'node14',
    treeshake: true,
  },
  // Annotation capture (browser runtime)
  {
    entry: { 'annotation-capture': './src/vue-annotation-capture.mjs' },
    format: ['iife'],
    outDir: 'dist',
    clean: false,
    platform: 'browser',
    target: 'es2015',
    treeshake: true,
  },
]);
