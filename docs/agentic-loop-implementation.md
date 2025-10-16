# Agentic Loop Implementation

## Overview

Our implementation follows the [AI SDK Manual Agent Loop pattern](https://ai-sdk.dev/cookbook/node/manual-agent-loop) for complete control over the agentic loop and tool execution.

## Key Principles from AI SDK Pattern

### 1. Message History Management ✅
- **AI SDK**: Maintains a `messages` array tracking the entire conversation
- **Our Implementation**: Uses `ref` for mutable message array in ReScript
- **Code**: Line 34 in `Agent__AgenticLoop.res`

```rescript
let messages = ref(Agent__Adapters__Vercel.messagesToVercel(history))
```

### 2. Add LLM Response Messages ✅
- **AI SDK**: After each LLM call, adds `response.messages` to history
- **Our Implementation**: Uses `result.response.messages` binding
- **Code**: Lines 53-55 in `Agent__AgenticLoop.res`

```rescript
// Add LLM generated messages to the message history (CRITICAL!)
let response = await result->Agent__Bindings__VercelAI.response
messages := Array.concat(messages.contents, response.messages)
```

### 3. Finish Reason Check ✅
- **AI SDK**: Uses `finishReason === 'tool-calls'` for loop control
- **Our Implementation**: Same pattern
- **Code**: Line 60 in `Agent__AgenticLoop.res`

```rescript
if finishReason == "tool-calls" {
```

### 4. Tool Result Format ✅
- **AI SDK**: Uses structured tool result messages with `role: 'tool'`
- **Our Implementation**: `makeToolResultMessage` helper in adapter
- **Code**: Lines 69-86 in `Agent__Adapters__Vercel.res`

```rescript
{
  role: "tool",
  content: Agent__Bindings__VercelAI.ArrayContent([
    {
      type_: "tool-result",
      toolCallId,
      toolName,
      result: JSON.Encode.string(result),
    },
  ]),
}
```

### 5. Loop Continuation ✅
- **AI SDK**: Recursive loop continues until no more tool calls
- **Our Implementation**: Inner `loop` function with recursion
- **Code**: Lines 37-128 in `Agent__AgenticLoop.res`

```rescript
let rec loop = async (vercelMessages: array<Agent__Bindings__VercelAI.message>) => {
  // ... execute LLM call
  if finishReason == "tool-calls" {
    // ... handle tools
    await loop(messages.contents)  // Continue loop
  } else {
    // ... complete task
  }
}
```

## Architecture Changes

### Message Type Updates

Updated `Agent__Bindings__VercelAI.message` to support:
- Union type for `content`: string OR array of tool results
- `role: "tool"` for tool result messages
- Structured `toolResultContent` type

### New Bindings

Added to `Agent__Bindings__VercelAI.res`:
- `response: streamTextResult => promise<response>` - Get LLM messages
- `toolCalls: streamTextResult => promise<array<toolCall>>` - Get tool calls
- `finishReason: streamTextResult => promise<string>` - Loop control

### Adapter Functions

Added to `Agent__Adapters__Vercel.res`:
- `makeToolResultMessage()` - Creates properly formatted tool result messages
- Updated `messageToVercel()` to use `StringContent` variant

### LLM Interface

Added to `Agent__LLM.res`:
- `streamTextWithVercelMessages()` - Accept pre-formatted Vercel messages for manual loop control

## Comparison with Original Implementation

### What Changed

| Aspect | Original | New |
|--------|----------|-----|
| Message tracking | Only tool results added | **All LLM messages added** |
| Loop control | `hasToolCalls` from stream | **`finishReason` from result** |
| Tool results | Custom Agent message | **Vercel tool message format** |
| Tool execution | Stream processor parsed calls | **`result.toolCalls` binding** |

### Why It Matters

1. **Message Continuity**: LLM needs to see its own previous responses (especially tool calls) to maintain conversation context
2. **Robust Loop Control**: `finishReason` is the official SDK way to determine completion
3. **Format Compatibility**: Tool results must match SDK's expected format for proper parsing
4. **Official API**: Using SDK bindings instead of stream parsing is more reliable

## Implementation Details

### Async Iterable Handling

The AI SDK's `fullStream` returns a `ReadableStream` that implements `Symbol.asyncIterator`. We handle this with a raw JavaScript `for-await-of` loop:

```rescript
let processAsyncIterable: (
  Agent__Bindings__VercelAI.AsyncIterableStream.t<'a>,
  'a => promise<unit>,
) => promise<unit> = %raw(`
  async function(iterable, handler) {
    for await (const chunk of iterable) {
      await handler(chunk);
    }
  }
`)
```

This generates clean JavaScript:
```javascript
let processAsyncIterable = (async function(iterable, handler) {
    for await (const chunk of iterable) {
      await handler(chunk);
    }
  });
```

### Why Not `iterator.next()`?

The `fullStream` is a `ReadableStream` with `Symbol.asyncIterator`, not a plain iterator. Attempting to call `.next()` directly will fail because:
- ReadableStream has `Symbol(Symbol.asyncIterator): ƒ ()` 
- You need to call the symbol to get the actual iterator
- `for-await-of` automatically handles this protocol

## Testing

Build the agent library:
```bash
cd libs/agent && make build
```

Run tests (when available):
```bash
cd libs/agent && make test
```

## References

- [AI SDK Manual Agent Loop](https://ai-sdk.dev/cookbook/node/manual-agent-loop)
- [AI SDK streamText API](https://ai-sdk.dev/docs/ai-sdk-core/stream-text)

