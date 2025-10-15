# @ask-the-llm/nextjs

Next.js middleware integration for ask-the-llm agent system.

## Overview

This library provides middleware functionality for integrating the ask-the-llm agent into Next.js applications.

## Installation

```bash
yarn install
```

## Usage

### Basic Middleware

```rescript
// middleware.res
open Nextjs

let middleware = (req: Middleware.Request.t): promise<Middleware.Response.t> => {
  // Your middleware logic here
  Middleware.Response.next()->Promise.resolve
}

// Configure which routes to match
let config = Middleware.config(~paths=["/api/:path*"])
```

### Example: API Route Protection

```rescript
let middleware = async (req: Middleware.Request.t): promise<Middleware.Response.t> => {
  let url = Middleware.Request.url(req)
  let headers = Middleware.Request.headers(req)

  // Check authentication
  switch headers->Webapi.Headers.get("authorization") {
  | Some(_token) => Middleware.Response.next()
  | None => Middleware.Response.json({"error": "Unauthorized"})
  }
}
```

## Development

### Build

```bash
make build
```

### Test

```bash
make test
```

### Watch Mode

```bash
make watch
```

### Format Code

```bash
make lint
```

## Project Structure

- `src/` - Source code
  - `Nextjs.res` - Main module
  - `Nextjs__Middleware.res` - Middleware implementation
- `test/` - Tests
- `Makefile` - Build tasks

## License

MIT
