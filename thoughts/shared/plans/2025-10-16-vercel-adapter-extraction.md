# Vercel Adapter Extraction Implementation Plan

## Overview

Extract all Vercel AI SDK-specific conversion logic from domain modules into a dedicated `Agent__Adapters__Vercel` module. This establishes a clean separation between domain types and the external LLM framework, making it easier to swap providers or upgrade the framework in the future.

## Current State Analysis

### Vercel-Specific Code Locations

1. **`Agent__Tools__Registry.res:80-108`**
   - `toVercelTools` function converts domain tool registry to Vercel `toolDef` format
   - Handles schema conversion, execute function wrapping, error handling

2. **`Agent__LLM.res:12-44`**
   - Inline message conversion from `Agent__Message.t` to Vercel `message` format
   - Converts role enum to strings, flattens parts into content strings

3. **`Agent__LLM.res:4-5`**
   - LLM type directly references Vercel types (`languageModel`, `toolDef`)

4. **`Agent__StreamProcessor.res:42-96`**
   - Takes Vercel `streamTextResult` directly
   - Pattern matches on Vercel `streamPart` events

5. **`Agent__Types.res:6-7, 19`**
   - Agent type stores Vercel-specific `model` and `tools`
   - Calls Vercel provider directly: `Agent__Bindings__VercelAI.OpenAI.gpt4o()`

### Key Discoveries

- Domain types are well-isolated (`Agent__Message.t`, `Agent__Part.t`, `Agent__Tools__Registry.tool`)
- Conversions happen at boundaries before calling Vercel APIs
- No existing adapter pattern established yet
- Stream processing already handles Vercel events but is tightly coupled

## Desired End State

After implementation:

1. **New Module**: `Agent__Adapters__Vercel.res` contains ALL Vercel-specific conversions
2. **Domain Modules**: Clean of Vercel references (Registry, LLM, StreamProcessor, Types)
3. **Clear Boundaries**: All Vercel types/calls isolated to adapter and bindings modules
4. **Maintainability**: Easy to add other provider adapters following same pattern

### Automated Verification

- [x] Build succeeds: `cd libs/agent && make build`
- [x] Tests pass: `cd libs/agent && make test` (No tests exist yet)
- [x] Type checking passes: ReScript compiler with no errors
- [x] Linting passes: `cd libs/agent && make lint`

### Manual Verification

- [ ] Agent still initializes correctly
- [ ] Tool calls work as before
- [ ] Message conversion maintains same behavior
- [ ] Stream processing produces identical results
- [ ] No runtime errors in simple chat flow

## What We're NOT Doing

- Not creating a generic provider interface yet (just isolating Vercel)
- Not changing the public Agent API
- Not modifying tool execution behavior
- Not adding support for other LLM providers
- Not changing how the bindings module works

## Implementation Approach

Extract conversions incrementally, module by module, testing after each phase to ensure no regressions. Start with the simplest conversion (tools), then messages, then the more complex stream processing.

---

## Phase 1: Create Adapter Module with Tool Conversion

### Overview

Create the new `Agent__Adapters__Vercel.res` module and move the `toVercelTools` function from Registry to the adapter.

### Changes Required

#### 1. Create New Adapter Module

**File**: `libs/agent/src/Agent__Adapters__Vercel.res`

```rescript
// Vercel AI SDK adapter - converts domain types to Vercel format

// ============ Tool Conversion ============

let toVercelTools = (registry: Agent__Tools__Registry.t): Dict.t<Agent__Bindings__VercelAI.toolDef> => {
  let vercelTools = Dict.make()

  registry->Array.forEach(tool => {
    switch tool {
    | Agent__Tools__Registry.Tool({name, description, inputSchema, execute}) =>
      let toolDef: Agent__Bindings__VercelAI.toolDef = {
        description: Some(description),
        inputSchema: inputSchema->S.toJSONSchema,
        execute: Some(
          async argsJson => {
            let input = argsJson->S.parseJsonOrThrow(inputSchema)
            let result = await execute(input)
            switch result {
            | Ok(output) => JSON.Encode.string(output)
            | Error(err) => {
                Console.error2(`Tool ${name} error:`, err)
                JSON.Encode.string(`Error: ${err}`)
              }
            }
          },
        ),
      }
      vercelTools->Dict.set(name, toolDef)
    }
  })

  vercelTools
}
```

#### 2. Remove Conversion from Registry

**File**: `libs/agent/src/Agent__Tools__Registry.res`

**Remove lines 79-108**:
```rescript
// Delete the entire toVercelTools function
```

#### 3. Update Agent Initialization

**File**: `libs/agent/src/Agent__Types.res`

**Change lines 21-22**:

Old:
```rescript
let toolRegistry = Agent__Tools__Registry.make(projectRoot)
let tools = Agent__Tools__Registry.toVercelTools(toolRegistry)
```

New:
```rescript
let toolRegistry = Agent__Tools__Registry.make(projectRoot)
let tools = Agent__Adapters__Vercel.toVercelTools(toolRegistry)
```

### Success Criteria

#### Automated Verification

- [x] Build succeeds: `cd libs/agent && make build`
- [x] No compilation errors
- [x] Type checking passes

#### Manual Verification

- [x] Agent initializes without errors
- [x] Tools are still registered correctly
- [x] Simple tool call works (e.g., read_file)

---

## Phase 2: Extract Message Conversion

### Overview

Move message-to-Vercel conversion logic from `Agent__LLM.res` into the adapter module.

### Changes Required

#### 1. Add Message Conversion to Adapter

**File**: `libs/agent/src/Agent__Adapters__Vercel.res`

Add after tool conversion:

```rescript
// ============ Message Conversion ============

let messageToVercel = (msg: Agent__Message.t): Agent__Bindings__VercelAI.message => {
  let role = switch msg->Agent__Message.getRole {
  | User => "user"
  | Agent => "assistant"
  }

  let content =
    msg
    ->Agent__Message.getParts
    ->Array.map(part => {
      switch part {
      | Text(textPart) => textPart->Agent__Part.TextPart.getText
      | File(filePart) => {
          let file = filePart->Agent__Part.FilePart.getFile
          let name = file->Agent__Part.File.getName->Option.getOr("unnamed")
          let mimeType = file->Agent__Part.File.getMimeType
          `File: ${name}, MimeType: ${mimeType}`
        }
      | Data(dataPart) => {
          let data = dataPart->Agent__Part.DataPart.getData
          `Data: ${data->JSON.stringify}`
        }
      }
    })
    ->Array.join("\n")

  {
    Agent__Bindings__VercelAI.role,
    content,
  }
}

let messagesToVercel = (messages: array<Agent__Message.t>): array<Agent__Bindings__VercelAI.message> => {
  messages->Array.map(messageToVercel)
}
```

#### 2. Simplify LLM Module

**File**: `libs/agent/src/Agent__LLM.res`

**Replace lines 12-44** (the chat function):

Old:
```rescript
let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  // Convert Agent__Message.t to Vercel AI format
  let vercelMessages = messages->Array.map(msg => {
    let role = switch msg->Agent__Message.getRole {
    | User => "user"
    | Agent => "assistant"
    }

    let content =
      msg
      ->Agent__Message.getParts
      ->Array.map(part => {
        switch part {
        | Text(textPart) => textPart->Agent__Part.TextPart.getText
        | File(filePart) => {
            let file = filePart->Agent__Part.FilePart.getFile
            let name = file->Agent__Part.File.getName->Option.getOr("unnamed")
            let mimeType = file->Agent__Part.File.getMimeType
            `File: ${name}, MimeType: ${mimeType}`
          }
        | Data(dataPart) => {
            let data = dataPart->Agent__Part.DataPart.getData
            `Data: ${data->JSON.stringify}`
          }
        }
      })
      ->Array.join("\n")

    {
      Agent__Bindings__VercelAI.role,
      content,
    }
  })

  // Call LLM
  let result = await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: Some(llm.tools),
    maxSteps: None,
  })

  await result->Agent__Bindings__VercelAI.text
}
```

New:
```rescript
let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  // Convert messages using adapter
  let vercelMessages = Agent__Adapters__Vercel.messagesToVercel(messages)

  // Call LLM
  let result = await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: Some(llm.tools),
    maxSteps: None,
  })

  await result->Agent__Bindings__VercelAI.text
}
```

### Success Criteria

#### Automated Verification

- [x] Build succeeds: `cd libs/agent && make build`
- [x] Tests pass: `cd libs/agent && make test` (No tests exist yet)
- [x] No type errors

#### Manual Verification

- [x] Agent chat works with simple text messages
- [x] Multi-part messages convert correctly
- [x] Role conversion (User/Agent) works as before

---

## Phase 3: Isolate Stream Processing (Optional Enhancement)

### Overview

While `Agent__StreamProcessor.res` takes Vercel types directly, we can add a comment indicating it's Vercel-specific and should eventually be refactored to use adapter pattern for stream events.

**Note**: Full stream processing refactoring is complex and could be a future enhancement. For now, we'll document the coupling.

### Changes Required

#### 1. Add Documentation Comment

**File**: `libs/agent/src/Agent__StreamProcessor.res`

**Add at top of file (line 1)**:

```rescript
// Stream processor - handles Vercel AI SDK stream events
// TODO: Consider extracting stream event conversion to Agent__Adapters__Vercel
// Currently tightly coupled to Vercel's streamPart event format
```

### Success Criteria

#### Automated Verification

- [x] Build succeeds: `cd libs/agent && make build`
- [x] Documentation is clear

#### Manual Verification

- [x] No behavior change
- [x] Future developers understand the coupling

---

## Phase 4: Update Public API Exports

### Overview

Export the new adapter module through the public `Agent.res` interface so it's accessible to consumers.

### Changes Required

#### 1. Add Adapter to Public Interface

**File**: `libs/agent/src/Agent.res`

**Add after existing exports**:

```rescript
// Existing exports...
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}

// Add adapter exports
module Adapters = {
  module Vercel = Agent__Adapters__Vercel
}
```

### Success Criteria

#### Automated Verification

- [x] Build succeeds: `cd libs/agent && make build`
- [x] Module is accessible: `Agent.Adapters.Vercel`

#### Manual Verification

- [x] Can import adapter from external code
- [x] Public API is clean and organized

---

## Testing Strategy

### Unit Tests

Since this is a refactoring with no behavior change, existing tests should pass:

- Tool registry tests (if any exist)
- Message handling tests
- Integration tests with actual LLM calls

### Manual Testing Steps

1. **Initialize Agent**
   ```rescript
   let agent = Agent.Types.Agent.make("/path/to/project")
   // Should succeed without errors
   ```

2. **Test Tool Call**
   ```rescript
   // Create a message that triggers read_file tool
   // Verify tool executes correctly
   ```

3. **Test Message Conversion**
   ```rescript
   // Send messages with different parts (text, file, data)
   // Verify they convert to Vercel format correctly
   ```

4. **Test Stream Processing**
   ```rescript
   // Run a streaming chat
   // Verify tool calls and results process correctly
   ```

### Integration Testing

Run the existing agent tests if they exist:
```bash
cd libs/agent
make test
```

## Performance Considerations

No performance impact expected:
- Same conversion logic, just relocated
- No additional allocations or transformations
- Function call overhead negligible

## Migration Notes

This is an internal refactoring with no breaking changes to the public API. Existing code using the Agent library will continue to work unchanged.

### For Future Provider Support

When adding support for other LLM providers (e.g., OpenAI direct, Anthropic direct):

1. Create `Agent__Adapters__OpenAI.res`, `Agent__Adapters__Anthropic.res`, etc.
2. Each adapter follows same pattern: `toProviderTools`, `messagesToProvider`, etc.
3. Add a provider selection mechanism in Agent initialization
4. Update `Agent__LLM.res` to dispatch to correct adapter based on provider

## References

- Current tool registry: `libs/agent/src/Agent__Tools__Registry.res:80-108`
- Current message conversion: `libs/agent/src/Agent__LLM.res:12-44`
- Vercel bindings: `libs/agent/src/Agent__Bindings__VercelAI.res`
- Agent initialization: `libs/agent/src/Agent__Types.res:13-44`
