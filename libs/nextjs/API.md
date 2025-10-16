# Ask-the-LLM API Routes Documentation

This document explains how to integrate the Ask-the-LLM API routes into your Next.js application.

## Overview

The Ask-the-LLM library provides Next.js API route handlers that serve an AI-powered interface for your Next.js application. It's implemented in ReScript and can be easily integrated into existing Next.js projects using the **Pages Router**.

## Requirements

- **Next.js** with Pages Router support
- **Node.js runtime** (API routes run on Node.js by default)

## Installation

First, ensure you have the package installed:

```bash
yarn add @ask-the-llm/nextjs
```

## API Routes Structure

The library provides two main handlers:

1. **UI Handler** (`/api/ask-the-llm`) - Serves the HTML interface for the Ask-the-LLM UI
2. **Chat Handler** (`/api/ask-the-llm/chat`) - Handles chat message POST requests

## Usage

### Step 1: Create API Route Directory

Create the API route directory structure in your Next.js project:

```bash
mkdir -p pages/api/ask-the-llm
```

### Step 2: Create the UI Route Handler

Create a file `pages/api/ask-the-llm/index.js` (or `.ts` for TypeScript):

**TypeScript Example: `pages/api/ask-the-llm/index.ts`**

```typescript
import { createUIHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';
import type { NextApiRequest, NextApiResponse } from 'next';

// Create the handler with isDev parameter
// Use true for development, false for production
const isDev = process.env.NODE_ENV !== 'production';

export default createUIHandler(isDev);
```

**JavaScript Example: `pages/api/ask-the-llm/index.js`**

```javascript
import { createUIHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';

// Create the handler with isDev parameter
// Use true for development, false for production
const isDev = process.env.NODE_ENV !== 'production';

export default createUIHandler(isDev);
```

### Step 3: Create the Chat Route Handler

Create a file `pages/api/ask-the-llm/chat.js` (or `.ts` for TypeScript):

**TypeScript Example: `pages/api/ask-the-llm/chat.ts`**

```typescript
import { createChatHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';
import type { NextApiRequest, NextApiResponse } from 'next';

export default createChatHandler();
```

**JavaScript Example: `pages/api/ask-the-llm/chat.js`**

```javascript
import { createChatHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';

export default createChatHandler();
```

### Step 4: Access the Interface

Once set up, you can access the Ask-the-LLM interface at:

```
http://localhost:3000/api/ask-the-llm
```

## API Reference

### `createUIHandler(isDev: boolean)`

Creates a Next.js API route handler that serves the Ask-the-LLM HTML interface.

**Parameters:**
- `isDev` (boolean): Whether to load the development or production client bundle
  - `true`: Loads client from `http://localhost:5173/src/main.tsx` (Vite dev server)
  - `false`: Loads client from `/ask-the-llm.es.js` (production bundle)

**Returns:** Next.js API route handler function `(req, res) => Promise<void>`

**Example:**
```typescript
import { createUIHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';

const isDev = process.env.NODE_ENV !== 'production';
export default createUIHandler(isDev);
```

### `createChatHandler()`

Creates a Next.js API route handler that processes chat messages.

**Returns:** Next.js API route handler function `(req, res) => Promise<void>`

**Request Body:**
```json
{
  "message": "Your question or message here"
}
```

**Success Response (200):**
```json
{
  "messageId": "unique-message-id"
}
```

**Error Responses:**
- `400 Bad Request`: Invalid or missing message
- `405 Method Not Allowed`: Non-POST request
- `500 Internal Server Error`: Agent processing error

**Example:**
```typescript
import { createChatHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';

export default createChatHandler();
```

## Advanced Configuration

### Custom API Route Paths

You can place the handlers at different paths by adjusting your file structure:

```
pages/
  api/
    custom-path/
      index.ts        -> Creates /api/custom-path
      chat.ts         -> Creates /api/custom-path/chat
```

Just ensure the client knows where to send requests by updating any configuration if needed.

### Environment Variables

The handlers automatically use the `PWD` environment variable to determine the project root. You can also set custom environment variables for the agent by creating a `.env` file in your project root.

### Agent Singleton

The library manages a singleton agent instance that is created on the first request. This ensures efficient resource usage and maintains state across requests.

## Testing

You can test the API routes using curl or any HTTP client:

```bash
# Test the UI endpoint
curl http://localhost:3000/api/ask-the-llm

# Test the chat endpoint
curl -X POST http://localhost:3000/api/ask-the-llm/chat \
  -H "Content-Type: application/json" \
  -d '{"message": "Hello, what can you help me with?"}'
```

## Troubleshooting

### Handler not found

If you get a 404 error, ensure:
1. The files are in the correct `pages/api/` directory
2. You've restarted your Next.js development server
3. The file extensions are correct (`.js`, `.ts`, `.jsx`, or `.tsx`)

### Module resolution errors

If you get import errors:
1. Ensure `@ask-the-llm/nextjs` is installed in your dependencies
2. Try clearing Next.js cache: `rm -rf .next`
3. Reinstall dependencies: `yarn install`

### Agent initialization errors

If the agent fails to initialize:
1. Check that the `PWD` environment variable is set
2. Ensure you have proper permissions in the project directory
3. Check the console logs for detailed error messages

## Complete Example

Here's a complete example of a Next.js project structure with Ask-the-LLM integrated:

```
my-nextjs-app/
├── pages/
│   ├── api/
│   │   └── ask-the-llm/
│   │       ├── index.ts       # UI handler
│   │       └── chat.ts        # Chat handler
│   ├── index.tsx              # Your home page
│   └── ...
├── package.json
├── next.config.js
└── .env
```

`pages/api/ask-the-llm/index.ts`:
```typescript
import { createUIHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';

const isDev = process.env.NODE_ENV !== 'production';
export default createUIHandler(isDev);
```

`pages/api/ask-the-llm/chat.ts`:
```typescript
import { createChatHandler } from '@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs';

export default createChatHandler();
```

That's it! Your Next.js application now has AI-powered assistance available at `/api/ask-the-llm`.

