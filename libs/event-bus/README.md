# @ask-the-llm/event-bus

Type-safe event bus with dual-mode architecture: **zero-cost in-process** and **JSON-serialized cross-process** communication.

## Architecture

- **LocalBus**: In-process events with zero serialization overhead
- **RemoteBus**: Cross-process events with JSON serialization at boundaries
- **Extensible GADTs**: Type-safe, user-extensible event variants
- **Transport-agnostic**: Works with STDIO, WebSocket, or custom transports

## Quick Example

```rescript
// Define event
module UserCreated: {
  type t
  let make: (~id: string, ~name: string) => t
} = { /* ... */ }

// In-process (zero overhead)
let bus = LocalBus.make()
LocalBus.emit(bus, UserCreated(user))

// Cross-process (serializes at boundary)
module MyRemoteBus = RemoteBus.Make(MyEvents, StdioTransport)
let remoteBus = MyRemoteBus.make(transport)
await MyRemoteBus.emit(remoteBus, UserCreated(user))
```

## Transports

**StdioTransport**: Use when your code runs inside a subprocess
```rescript
module MyBus = EventBus.RemoteBus.Make(MyEvents, EventBus.StdioTransport)
let bus = MyBus.make(())  // Pass unit
```

**SubprocessTransport**: Use when controlling a subprocess
```rescript
let proc = EventBus.Subprocess.spawn("./subprocess.mjs")
module MyBus = EventBus.RemoteBus.Make(MyEvents, EventBus.SubprocessTransport)
let bus = MyBus.make(proc)  // Pass subprocess
```

## Defining Events

### Schema-Driven Pattern

Use `MakeEvent` to auto-generate JSON serialization:

```rescript
module UserCreatedConfig = {
  type t = {id: string, name: string}
  let name = "user.created"
  let schema = S.object(s => {
    id: s.field("id", S.string),
    name: s.field("name", S.string),
  })
}
module UserCreated = EventBus.MakeEvent.Make(UserCreatedConfig)

// Combine into EventType
type events = | UserCreated(UserCreated.t)
let eventName = event => switch event { | UserCreated(_) => UserCreated.name }
let toJson = event => switch event { | UserCreated(e) => UserCreated.toJson(e) }
let fromJson = (name, json) => {
  if name == UserCreated.name {
    UserCreated.fromJson(json)->Option.map(e => UserCreated(e))
  } else {
    None
  }
}
```

See `test/Fixtures__SchemaEvents.res` for complete example.

## Wire Protocol

Newline-delimited JSON envelope over STDIO:
```json
{"id": "...", "timestamp": 123, "eventName": "user.created", "data": {...}}
```

## Building

```bash
make build   # Compile
make dev     # Watch mode
make clean   # Clean
```

## Testing

### Running Tests

```bash
# Run all tests
make test

# Run specific test suites
yarn vitest test/integration/      # Integration tests only
yarn vitest test/unit/             # Unit tests only

# Watch mode for development
yarn vitest --watch
```

### Test Structure

- **Integration tests**: Test STDIO transport with subprocess fixtures
- **Unit tests**: Test individual components (future)
- **E2E tests**: Test full agent communication scenarios (future)

See `test/README.md` for detailed testing documentation.

## Examples

See `/examples/BasicUsage.res` for complete usage.
