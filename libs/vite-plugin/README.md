# @ask-the-llm/vite-plugin

A Vite plugin that integrates the Ask-the-LLM agent into your Vite development server.

## Installation

```bash
npm install @ask-the-llm/vite-plugin
# or
yarn add @ask-the-llm/vite-plugin
# or
pnpm add @ask-the-llm/vite-plugin
```

## Usage

Add the plugin to your `vite.config.ts`:

```typescript
import { defineConfig } from 'vite';
import { askTheLlmPlugin } from '@ask-the-llm/vite-plugin';

export default defineConfig({
  plugins: [
    askTheLlmPlugin({
      isDev: true,
      isLightTheme: true,
      entrypointUrl: 'http://localhost:5173/api/ask-the-llm',
    }),
  ],
});
```

## Options

### `isDev`

- **Type:** `boolean`
- **Default:** `process.env.NODE_ENV !== "production"`

Whether to run in development mode. In development mode, additional debugging features may be enabled.

### `isLightTheme`

- **Type:** `boolean`
- **Default:** `true`

Whether to use light theme for the UI. Set to `false` for dark theme.

### `entrypointUrl`

- **Type:** `string`
- **Default:** `"http://localhost:3000/api/ask-the-llm"`

The entrypoint URL for the Ask-the-LLM API. This should match the URL where your Vite server is running.

### `clientUrl`

- **Type:** `string`
- **Default:** `"http://localhost:5173/src/Main.js"`

The URL where the Ask-the-LLM client script is served.

## API Routes

The plugin automatically sets up the following API routes:

- `GET /api/ask-the-llm` - Serves the Ask-the-LLM UI
- `POST /api/ask-the-llm/chat` - Handles chat messages
- `GET /api/ask-the-llm/chat-sse` - Server-Sent Events endpoint for streaming responses

## License

ISC

