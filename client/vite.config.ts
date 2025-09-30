import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'
import fs from 'fs'
import path from 'path'

// https://vite.dev/config/
export default defineConfig(({ command, mode }) => {
  // Development mode configuration
  if (command === 'serve') {
    return {
      plugins: [react()],
      define: {
        'process.env': {},
        'global': 'globalThis',
      },
      server: {
        port: 5173,
        host: true,
        cors: true,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type'
        }
      },
      preview: {
        port: 5173,
        host: true,
        cors: true,
        headers: {
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
          'Access-Control-Allow-Headers': 'Content-Type'
        }
      }
    }
  }

  // Production/library build configuration
  const basePlugins = [react()]


  return {
    plugins: basePlugins,
    define: {
      'process.env': {},
      'global': 'globalThis',
    },
    build: {
      lib: {
        entry: './src/main.tsx',
        name: 'AskTheLLM',
        fileName: (format) => `ask-the-llm.${format}.js`,
        formats: ['umd', 'es']
      },
      rollupOptions: {
        external: [],
        output: {
          globals: {},
          exports: 'named'
        }
      },
      outDir: 'dist',
      sourcemap: true,
      target: 'es2015',
      minify: false,
      watch: mode === 'development' ? {
        include: ['src/**']
      } : null,
    },
    server: {
      port: 5173,
      host: true,
      cors: true,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      }
    },
    preview: {
      port: 5173,
      host: true,
      cors: true,
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
      }
    }
  }
})
