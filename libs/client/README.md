# client-rescript

ReScript + React component library for internal monorepo use.

## Stack

- [ReScript](https://rescript-lang.org) 11.0 with @rescript/react and JSX v4
- ES6 modules (ReScript code compiled to `.res.mjs` files)
- CSS Modules for component styling
- TypeScript type definitions (auto-generated via genType)
- Vitest for testing

## Development

Build the library:

```sh
make build
```

Watch mode for development:

```sh
make dev
```

Run tests:

```sh
make test
```

## Usage

**ReScript:**
```rescript
open Client
<Button onClick={handleClick}> {React.string("Click me")} </Button>
```

**TypeScript:**
```typescript
import { Button_make as Button } from '@libs/client/src/Client.gen'
<Button onClick={handleClick}>Click me</Button>
```

## Commands

Run `make` or `make help` to see all available commands.
