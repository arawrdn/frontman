import { defineConfig } from 'vite';
import createReScriptPlugin from '@jihchi/vite-plugin-rescript';
import tailwindcss from "@tailwindcss/vite";
import path from 'path';

export default defineConfig({
  plugins: [createReScriptPlugin(), tailwindcss()],
  resolve: {
    alias: {
      '@': path.resolve(__dirname, './src'),
    },
  },
});