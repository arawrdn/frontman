# Ask-the-LLM Middleware Documentation

This document explains how to integrate the Ask-the-LLM middleware into your Next.js application.

## Overview

The Ask-the-LLM middleware provides a route (`/ask-the-llm`) that serves an AI-powered interface for your Next.js application. It's implemented in ReScript and can be easily integrated into existing Next.js projects.

## Installation

First, ensure you have the package installed:

```bash
yarn add @ask-the-llm/nextjs
```

## Usage

There are two scenarios for integrating the middleware:

### Scenario 1: No existing middleware.ts file

If your Next.js project doesn't have a middleware file yet, create one in the root of your `src` directory (or project root if not using `src`):

**TypeScript Example: `src/middleware.ts`**

```typescript
import { createMiddleware, config } from '@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs';

let middleware = createMiddleware(true);

export { middleware, config };
```

**JavaScript Example: `middleware.js`**

```javascript
import { createMiddleware, config } from '@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs';

let middleware = createMiddleware(true);

export { middleware, config };
```

That's it! The middleware will now handle the `/ask-the-llm` route automatically.

The `createMiddleware` function takes a boolean parameter to enable or disable the middleware functionality.

### Scenario 2: Existing middleware.ts file

If you already have a middleware file with your own logic, you need to compose the Ask-the-LLM middleware with your existing middleware:

**TypeScript Example: `src/middleware.ts`**

```typescript
import { createMiddleware } from '@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs';
import { NextRequest, NextResponse } from 'next/server';

const askTheLlmMiddleware = createMiddleware(true);

export async function middleware(request: NextRequest) {
  // First, let Ask-the-LLM middleware handle its routes
  const pathname = new URL(request.url).pathname;
  
  if (pathname === '/ask-the-llm' || pathname.startsWith('/ask-the-llm/')) {
    return await askTheLlmMiddleware(request);
  }

  // Your existing middleware logic here
  // Example: Authentication check
  const token = request.cookies.get('token');
  if (!token && pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Example: Add custom headers
  const response = NextResponse.next();
  response.headers.set('x-custom-header', 'my-value');
  
  return response;
}

export const config = {
  matcher: [
    '/ask-the-llm',
    '/ask-the-llm/:path*',
    '/dashboard/:path*',
    // Add your other routes here
  ]
};
```

**JavaScript Example: `middleware.js`**

```javascript
import { createMiddleware } from '@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs';
import { NextResponse } from 'next/server';

const askTheLlmMiddleware = createMiddleware(true);

async function middleware(request) {
  // First, let Ask-the-LLM middleware handle its routes
  const pathname = new URL(request.url).pathname;
  
  if (pathname === '/ask-the-llm' || pathname.startsWith('/ask-the-llm/')) {
    return await askTheLlmMiddleware(request);
  }

  // Your existing middleware logic here
  // Example: Authentication check
  const token = request.cookies.get('token');
  if (!token && pathname.startsWith('/dashboard')) {
    return NextResponse.redirect(new URL('/login', request.url));
  }

  // Example: Add custom headers
  const response = NextResponse.next();
  response.headers.set('x-custom-header', 'my-value');
  
  return response;
}

const config = {
  matcher: [
    '/ask-the-llm',
    '/ask-the-llm/:path*',
    '/dashboard/:path*',
    // Add your other routes here
  ]
};

export { middleware, config };
```