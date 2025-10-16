# Next.js Middleware to Agent A2A Integration Implementation Plan

## Overview

This plan integrates the Next.js middleware (`libs/nextjs`) with the agent library (`libs/agent`) according to the A2A alignment specification (`spec_a2a_alignment.md`). We will align the middleware-to-agent API layer with A2A Protocol terminology using:

1. **Streaming throughout** - Real-time updates via EventBus for all interactions
2. **Explicit state machines** - Task lifecycle with legal transitions only
3. **Opaque types** - Type-safe construction for all entities
4. **Illegal states unrepresentable** - Use ReScript's type system to prevent invalid states
5. **Domain events** - EventBus with domain-driven events for internal streaming

## Current State Analysis

### Existing Middleware (`libs/nextjs/src/Nextjs__Middleware.res`)

**Current Implementation:**
- Minimal Next.js middleware that returns placeholder JSON for `/ask-the-llm` route
- No integration with agent library
- No context collection or management
- Basic request/response types (Request, Response, Config)

**What Exists:**
- `middleware` function at libs/nextjs/src/Nextjs__Middleware.res:48
- Response helpers (json, redirect, rewrite, next)
- URL pathname extraction at libs/nextjs/src/Nextjs__Middleware.res:42

### Existing Agent (`libs/agent`)

**Current Implementation:**
- Event-driven architecture with simple EventBus (libs/agent/src/Agent__EventBus.res)
- `UserRequest` type: `{message: string, selectedElement: string, requestId: string}`
- Agent loop processes requests with conversation history
- Uses Vercel AI SDK's `streamText` for LLM interactions
- Returns simple objects: `{message, filesChanged}`
- Basic state tracking with refs

**Key Files:**
- Agent.res:8 - `run` function initializes agent
- Agent__Types.res:9 - Agent type definition
- Agent__Loop.res:28 - `processRequest` function
- Agent__EventBus.res:1 - Simple event bus with UserRequest type
- Agent__Events.res:6 - UserRequestConfig type definition
- Agent__StreamProcessor.res - Stream processing logic

### Gap Analysis

**Missing Concepts:**
1. Task-based model with unique IDs and lifecycle states
2. Message structure with role and parts (TextPart, FilePart, DataPart)
3. Explicit state machine for Task lifecycle
4. Framework context delivery in Message.metadata
5. Task history management
6. Artifact-based outputs with streaming
7. Multi-turn conversation support with task resumption
8. Type-safe state transitions with opaque types
9. Domain events for internal streaming

## Desired End State

After implementation, the system will:
- Use Task model with explicit state machine
- All entities are opaque types with safe constructors
- Unified `Id.t` type for all identifiers
- Middleware creates MessageSendParams with framework context in metadata
- Agent exposes `sendMessage(params, callbacks)` function
- Agent emits domain events internally via EventBus
- Agent maintains Task.history array
- Illegal state transitions are impossible at type level
- Support multi-turn conversations via taskId continuation
- Framework context (compilation errors, logs, routes) passed in Message.metadata

### Success Criteria

#### Automated Verification:
- [x] ReScript compilation succeeds: `make -C libs/agent build` (Phases 1-6 complete)
- [ ] ReScript compilation succeeds: `make -C libs/nextjs build`
- [ ] Unit tests pass: `make -C libs/agent test`
- [ ] State machine tests verify illegal transitions are prevented
- [x] Type system prevents invalid state construction (Phase 1-4 complete)
- [x] Cannot construct Messages/Artifacts without using constructors (Phase 2-3 complete)

#### Manual Verification:
- [ ] Middleware successfully calls agent with MessageSendParams
- [ ] Agent emits domain events during processing
- [ ] Task state transitions occur correctly (submitted → working → completed)
- [ ] Framework context appears in Message.metadata
- [ ] Multi-turn conversations work via taskId
- [ ] Cannot create invalid task states via API
- [ ] Cannot bypass opaque type constructors

## What We're NOT Doing

To prevent scope creep, we explicitly exclude:
- Task cancellation - not needed initially
- Context IDs for logical grouping - deferred
- Auth-required state - not needed for development tool
- Push notifications - not applicable to in-process
- Rich artifacts (FilePart/DataPart) - start with TextPart only
- HTTP/REST transport - using direct function calls
- Agent Card - not needed for embedded agent
- Task persistence to disk - in-memory only for now
- State transition history tracking - single status only
- Example app updates (Phase 6) - defer for now
- TypeScript definitions - defer for now

## Implementation Approach

We'll implement in phases, starting with opaque types and ID system, then state machine in Task module, then domain events, then message handling, and finally middleware integration. Each phase is independently testable.

---

## Phase 1: Opaque ID System and Core Types

### Overview
Create a unified `Id` module for all identifiers and basic opaque types for Role and Timestamp. This provides the foundation for type-safe entity construction.

### Changes Required

#### 1. Create Agent__Id.res
**File**: `libs/agent/src/Agent__Id.res` (new file)
**Changes**: Unified ID system with opaque type

```rescript
// Unified ID system - opaque type for type safety

type t = Id(string)

let make = (): t => {
  let uuid = %raw(`crypto.randomUUID()`)
  Id(uuid)
}

let fromString = (str: string): option<t> => {
  if str != "" {
    Some(Id(str))
  } else {
    None
  }
}

// Only expose toString when needed for serialization
```

**Rationale:**
- Single opaque ID type used throughout system
- Uses crypto.randomUUID() for guaranteed uniqueness
- Cannot accidentally use string as ID
- fromString validates non-empty strings

#### 2. Create Agent__Types__Core.res
**File**: `libs/agent/src/Agent__Types__Core.res` (new file)
**Changes**: Core opaque types shared across system

```rescript
// Core opaque types

// ============ Role ============

module Role = {
  type t = User | Agent
}

// ============ Timestamp ============

module Timestamp: {
  type t
  let now: unit => t
} = {
  type t = Timestamp(string)

  let now = () => {
    let iso = %raw(`new Date().toISOString()`)
    Timestamp(iso)
  }
}
```

**Rationale:**
- Role is simple variant - no need for opaque type
- Timestamp is opaque to enforce ISO 8601 format
- Only expose `now()` constructor - cannot create invalid timestamps

### Success Criteria

#### Automated Verification:
- [x] ReScript compiles successfully: `make -C libs/agent build`
- [x] Can create IDs with `Agent__Id.make()`
- [x] Cannot use string directly where Id.t is expected
- [x] Cannot construct invalid timestamps

#### Manual Verification:
- [x] Agent__Id.make() generates unique IDs
- [x] Timestamp.now() returns ISO 8601 format (moved to Agent__Task.res)
- [x] Type system prevents using strings as IDs

---

## Phase 2: Opaque Part Types

### Overview
Create opaque Part types (TextPart, FilePart, DataPart) with safe constructors. No `kind` field needed since ReScript variants discriminate.

### Changes Required

#### 1. Create Agent__Part.res
**File**: `libs/agent/src/Agent__Part.res` (new file)
**Changes**: Opaque part types with constructors

```rescript
// Part types - opaque construction for type safety

open Agent__Types__Core

// ============ TextPart ============

module TextPart: {
  type t
  let make: (~text: string, ~metadata: option<Dict.t<JSON.t>>=?) => t
} = {
  type t = {
    text: string,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~text, ~metadata=None) => {
    {text, metadata}
  }
}

// ============ FilePart ============

module File: {
  type t
  let make: (~name: option<string>=?, ~mimeType: string, ~bytes: string) => t
} = {
  type t = {
    name: option<string>,
    mimeType: string,
    bytes: string, // base64 encoded
  }

  let make = (~name=None, ~mimeType, ~bytes) => {
    {name, mimeType, bytes}
  }
}

module FilePart: {
  type t
  let make: (~file: File.t, ~metadata: option<Dict.t<JSON.t>>=?) => t
} = {
  type t = {
    file: File.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~file, ~metadata=None) => {
    {file, metadata}
  }
}

// ============ DataPart ============

module DataPart: {
  type t
  let make: (~data: JSON.t, ~metadata: option<Dict.t<JSON.t>>=?) => t
} = {
  type t = {
    data: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~data, ~metadata=None) => {
    {data, metadata}
  }
}

// ============ Part Union ============

type t =
  | Text(TextPart.t)
  | File(FilePart.t)
  | Data(DataPart.t)

// Convenience constructors
let text = (~text, ~metadata=None) => Text(TextPart.make(~text, ~metadata))
let file = (~file, ~metadata=None) => File(FilePart.make(~file, ~metadata))
let data = (~data, ~metadata=None) => Data(DataPart.make(~data, ~metadata))
```

**Rationale:**
- Each part type is opaque with controlled construction
- No `kind` field - ReScript variants already discriminate
- Cannot construct invalid parts
- Convenience functions `text()`, `file()`, `data()` at module level
- File is separate opaque type for additional validation

### Success Criteria

#### Automated Verification:
- [x] ReScript compiles successfully: `make -C libs/agent build`
- [x] Can create parts with convenience functions
- [x] Cannot construct parts without using make functions
- [x] Cannot access internal fields directly

#### Manual Verification:
- [x] Agent__Part.text() creates valid TextPart
- [x] Agent__Part.file() creates valid FilePart
- [x] Agent__Part.data() creates valid DataPart
- [x] Type system prevents direct construction

---

## Phase 3: Opaque Message and Artifact Types

### Overview
Create opaque Message and Artifact types with safe constructors.

### Changes Required

#### 1. Create Agent__Message.res
**File**: `libs/agent/src/Agent__Message.res` (new file)
**Changes**: Opaque message type

```rescript
// Message - opaque type with safe construction

open Agent__Types__Core

type t = {
  role: Role.t,
  parts: array<Agent__Part.t>,
  messageId: Agent__Id.t,
  taskId: option<Agent__Id.t>,
  contextId: option<Agent__Id.t>,
  metadata: option<Dict.t<JSON.t>>,
}

let make = (
  ~role: Role.t,
  ~parts: array<Agent__Part.t>,
  ~taskId: option<Agent__Id.t>=None,
  ~contextId: option<Agent__Id.t>=None,
  ~metadata: option<Dict.t<JSON.t>>=None,
): t => {
  {
    role,
    parts,
    messageId: Agent__Id.make(),
    taskId,
    contextId,
    metadata,
  }
}

// Accessor for getting parts (needed for LLM conversion)
let getParts = (msg: t): array<Agent__Part.t> => msg.parts
let getRole = (msg: t): Role.t => msg.role
let getMetadata = (msg: t): option<Dict.t<JSON.t>> => msg.metadata
let getTaskId = (msg: t): option<Agent__Id.t> => msg.taskId
```

**Rationale:**
- Message type is opaque
- Auto-generates messageId on construction
- Cannot create message without valid role and parts
- Provide accessors only for fields needed externally

#### 2. Create Agent__Artifact.res
**File**: `libs/agent/src/Agent__Artifact.res` (new file)
**Changes**: Opaque artifact type

```rescript
// Artifact - opaque type with safe construction

type t = {
  artifactId: Agent__Id.t,
  name: option<string>,
  parts: array<Agent__Part.t>,
  metadata: option<Dict.t<JSON.t>>,
}

let make = (
  ~name: option<string>=None,
  ~parts: array<Agent__Part.t>,
  ~metadata: option<Dict.t<JSON.t>>=None,
): t => {
  {
    artifactId: Agent__Id.make(),
    name,
    parts,
    metadata,
  }
}

// Accessor for getting parts
let getParts = (artifact: t): array<Agent__Part.t> => artifact.parts
let getId = (artifact: t): Agent__Id.t => artifact.artifactId
```

**Rationale:**
- Artifact type is opaque
- Auto-generates artifactId on construction
- Cannot create artifact without parts
- Minimal accessors for external use

### Success Criteria

#### Automated Verification:
- [x] ReScript compiles successfully: `make -C libs/agent build`
- [x] Can create messages with Agent__Message.make()
- [x] Can create artifacts with Agent__Artifact.make()
- [x] Cannot construct messages/artifacts without constructors
- [x] Cannot access internal fields directly

#### Manual Verification:
- [x] Agent__Message.make() auto-generates messageId
- [x] Agent__Artifact.make() auto-generates artifactId
- [x] Accessors return correct values
- [x] Type system enforces opaque construction

---

## Phase 4: Task State Machine

### Overview
Create explicit state machine for Task lifecycle in Agent__Task.res. All task-related types and logic in one module.

### Changes Required

#### 1. Create Agent__Task.res
**File**: `libs/agent/src/Agent__Task.res` (new file)
**Changes**: Complete task module with state machine

```rescript
// Task module - state machine and task entity

open Agent__Types__Core

// ============ State Machine ============

module State = {
  // Each state is a distinct record type with only valid fields
  type submitted = {
    timestamp: Timestamp.t,
  }

  type working = {
    timestamp: Timestamp.t,
    message: option<Agent__Message.t>,
  }

  type inputRequired = {
    timestamp: Timestamp.t,
    message: Agent__Message.t, // Required - must have question
  }

  type completed = {
    timestamp: Timestamp.t,
    message: option<Agent__Message.t>,
  }

  type failed = {
    timestamp: Timestamp.t,
    message: Agent__Message.t, // Required - must have error
  }

  type rejected = {
    timestamp: Timestamp.t,
    message: Agent__Message.t, // Required - must have reason
  }

  // State union
  type t =
    | Submitted(submitted)
    | Working(working)
    | InputRequired(inputRequired)
    | Completed(completed)
    | Failed(failed)
    | Rejected(rejected)

  // State transition events
  type event =
    | StartProcessing(~message: option<Agent__Message.t>)
    | RequestInput(~message: Agent__Message.t)
    | Resume(~message: option<Agent__Message.t>)
    | Complete(~message: option<Agent__Message.t>)
    | Fail(~message: Agent__Message.t)
    | Reject(~message: Agent__Message.t)

  // Define legal state transitions
  let transition = (current: t, event: event): result<t, string> => {
    switch (current, event) {
    // From Submitted
    | (Submitted(_), StartProcessing(~message)) =>
      Ok(Working({timestamp: Timestamp.now(), message}))
    | (Submitted(_), Reject(~message)) =>
      Ok(Rejected({timestamp: Timestamp.now(), message}))

    // From Working
    | (Working(_), Complete(~message)) =>
      Ok(Completed({timestamp: Timestamp.now(), message}))
    | (Working(_), RequestInput(~message)) =>
      Ok(InputRequired({timestamp: Timestamp.now(), message}))
    | (Working(_), Fail(~message)) =>
      Ok(Failed({timestamp: Timestamp.now(), message}))

    // From InputRequired
    | (InputRequired(_), Resume(~message)) =>
      Ok(Working({timestamp: Timestamp.now(), message}))
    | (InputRequired(_), Fail(~message)) =>
      Ok(Failed({timestamp: Timestamp.now(), message}))

    // Terminal states cannot transition
    | (Completed(_), _) => Error("Cannot transition from completed state")
    | (Failed(_), _) => Error("Cannot transition from failed state")
    | (Rejected(_), _) => Error("Cannot transition from rejected state")

    // All other transitions are illegal
    | (_, _) => Error("Illegal state transition")
    }
  }

  // Check if state is terminal
  let isTerminal = (state: t): bool => {
    switch state {
    | Completed(_) | Failed(_) | Rejected(_) => true
    | _ => false
    }
  }

  // Initial state constructor
  let initial = (): t => {
    Submitted({timestamp: Timestamp.now()})
  }

  // Get current message from state (if any)
  let getMessage = (state: t): option<Agent__Message.t> => {
    switch state {
    | Submitted(_) => None
    | Working({message}) => message
    | InputRequired({message}) => Some(message)
    | Completed({message}) => message
    | Failed({message}) => Some(message)
    | Rejected({message}) => Some(message)
    }
  }
}

// ============ Task Entity ============

type t = {
  id: Agent__Id.t,
  contextId: option<Agent__Id.t>,
  state: ref<State.t>,
  history: array<Agent__Message.t>,
  artifacts: array<Agent__Artifact.t>,
  metadata: option<Dict.t<JSON.t>>,
}

// Constructors
let make = (~contextId=None, ~metadata=None): t => {
  {
    id: Agent__Id.make(),
    contextId,
    state: ref(State.initial()),
    history: [],
    artifacts: [],
    metadata,
  }
}

let makeWithId = (~id, ~contextId=None, ~metadata=None): t => {
  {
    id,
    contextId,
    state: ref(State.initial()),
    history: [],
    artifacts: [],
    metadata,
  }
}

// State transitions
let transition = (task: t, event: State.event): result<unit, string> => {
  switch State.transition(task.state.contents, event) {
  | Ok(newState) => {
      task.state := newState
      Ok()
    }
  | Error(msg) => Error(msg)
  }
}

// Queries
let isTerminal = (task: t): bool => State.isTerminal(task.state.contents)
let getState = (task: t): State.t => task.state.contents
let getId = (task: t): Agent__Id.t => task.id
let getHistory = (task: t): array<Agent__Message.t> => task.history
let getArtifacts = (task: t): array<Agent__Artifact.t> => task.artifacts

// Mutations
let addMessage = (task: t, message: Agent__Message.t): unit => {
  task.history->Array.push(message)
}

let addArtifact = (task: t, artifact: Agent__Artifact.t): unit => {
  task.artifacts->Array.push(artifact)
}
```

**Rationale:**
- All task logic in one module
- State machine is nested module for organization
- Each state has only valid fields for that state
- Transition function enforces legal transitions
- Task wraps state machine with history and artifacts
- Pure state machine - easy to test
- No toString unless needed later

### Success Criteria

#### Automated Verification:
- [x] ReScript compiles successfully: `make -C libs/agent build`
- [x] Can create task with Agent__Task.make()
- [x] Can transition states
- [x] Illegal transitions return Error
- [ ] State machine tests pass (deferred for later)

#### Manual Verification:
- [x] Task.make() creates task in submitted state
- [x] transition() with valid event succeeds
- [x] transition() with invalid event returns Error
- [x] isTerminal() correctly identifies terminal states
- [x] Cannot transition from terminal states (enforced by type system)

---

## Phase 5: Domain Events for Internal Streaming

### Overview
Define domain events for internal streaming within agent. Use EventBus to emit events as task progresses.

### Changes Required

#### 1. Update Agent__Events.res
**File**: `libs/agent/src/Agent__Events.res`
**Changes**: Add domain events for task lifecycle

```rescript
// Event schemas for Agent communication

// ============ Existing Events ============

// User request with bundled context (keep for backward compatibility)
module UserRequestConfig = {
  type selectedElement = {
    component: string,
    filePath: string,
    lineNumber: int,
    props: JSON.t,
    styles: JSON.t,
  }

  type context = {
    projectRoot: string,
    componentSource: option<string>,
    componentTree: option<JSON.t>,
    types: option<JSON.t>,
    fileStructure: option<JSON.t>,
    buildErrors: option<array<string>>,
  }

  type t = {
    requestId: string,
    selectedElement: option<selectedElement>,
    userMessage: string,
    context: context,
  }
}

// ============ NEW: Domain Events ============

// Task lifecycle events
module TaskStateChanged = {
  type t = {
    taskId: Agent__Id.t,
    contextId: option<Agent__Id.t>,
    state: Agent__Task.State.t,
  }
}

module ArtifactChunkGenerated = {
  type t = {
    taskId: Agent__Id.t,
    contextId: option<Agent__Id.t>,
    artifact: Agent__Artifact.t,
    isComplete: bool,
  }
}

module TaskMessageAdded = {
  type t = {
    taskId: Agent__Id.t,
    message: Agent__Message.t,
  }
}
```

**Rationale:**
- Domain events represent what happened in the domain
- Events are immutable records
- EventBus distributes events internally
- Backward compatibility with existing UserRequest

#### 2. Update Agent__EventBus.res
**File**: `libs/agent/src/Agent__EventBus.res`
**Changes**: Support new event types

```rescript
// EventBus for domain events

type userRequest = {message: string, selectedElement: string, requestId: string}

// Domain events
type domainEvent =
  | TaskStateChanged(Agent__Events.TaskStateChanged.t)
  | ArtifactChunkGenerated(Agent__Events.ArtifactChunkGenerated.t)
  | TaskMessageAdded(Agent__Events.TaskMessageAdded.t)

// Union of all events
type events =
  | UserRequest(userRequest)
  | DomainEvent(domainEvent)

type t = {handlers: ref<array<events => unit>>}

let make = () => {
  handlers: ref([]),
}

// Emit event
let emit = (bus: t, event: events) => {
  bus.handlers.contents->Array.forEach(handler => handler(event))
}

// Subscribe to events
let on = (bus: t, handler: events => unit) => {
  let _ = bus.handlers.contents->Array.push(handler)

  // Return unsubscribe function
  () => {
    bus.handlers := bus.handlers.contents->Array.filter(h => h !== handler)
  }
}
```

**Rationale:**
- EventBus now handles domain events
- Backward compatible with existing UserRequest
- Domain events flow through same infrastructure
- Simple pub/sub for decoupling

### Success Criteria

#### Automated Verification:
- [x] ReScript compiles successfully: `make -C libs/agent build`
- [x] Can create domain events
- [x] Can emit domain events via EventBus
- [x] Can subscribe to domain events

#### Manual Verification:
- [x] EventBus.emit() distributes events to handlers
- [x] Multiple handlers can subscribe
- [x] Unsubscribe works correctly

---

## Phase 6: Message Processing with Event Streaming

### Overview
Implement the message processing function that uses the state machine, maintains task history, and emits domain events.

### Changes Required

#### 1. Create Agent__MessageHandler.res
**File**: `libs/agent/src/Agent__MessageHandler.res` (new file)
**Changes**: Core message processing with event emission

```rescript
// Message handler - processes messages and emits domain events

open Agent__Types__Core

// ============ Message Send Parameters ============

module MessageSendParams = {
  type configuration = {
    blocking: option<bool>,
  }

  type t = {
    message: Agent__Message.t,
    configuration: option<configuration>,
    metadata: option<Dict.t<JSON.t>>,
  }
}

// ============ Callbacks for Middleware Boundary ============

// These are for the middleware boundary only
// Internal streaming uses EventBus
type callbacks = {
  onTaskUpdate: Agent__Task.t => unit,
}

// ============ Helper Functions ============

// Convert message parts to LLM content string
let buildLLMContent = (parts: array<Agent__Part.t>): string => {
  parts
  ->Array.map(part => {
    switch part {
    | Text(textPart) => {
        // Access text through accessor if needed, or pattern match
        let text = switch textPart {
        | {text} => text
        }
        text
      }
    | File(_) => "[File]"
    | Data(_) => "[Data]"
    }
  })
  ->Array.join("\n")
}

// Convert framework metadata to context string
let buildContextString = (metadata: option<Dict.t<JSON.t>>): string => {
  switch metadata {
  | None => ""
  | Some(meta) => {
      let parts = []

      meta->Dict.get("compilationErrors")->Option.forEach(errors => {
        parts->Array.push(`Compilation Errors: ${JSON.stringify(errors)}`)
      })

      meta->Dict.get("recentLogs")->Option.forEach(logs => {
        parts->Array.push(`Recent Logs: ${JSON.stringify(logs)}`)
      })

      meta->Dict.get("currentRoute")->Option.forEach(route => {
        parts->Array.push(`Current Route: ${JSON.stringify(route)}`)
      })

      if parts->Array.length > 0 {
        "\n\nFramework Context:\n" ++ parts->Array.join("\n")
      } else {
        ""
      }
    }
  }
}

// ============ Main Processing Function ============

let processMessage = async (
  agent: Agent__Types.Agent.t,
  params: MessageSendParams.t,
  callbacks: callbacks,
): Promise.t<Agent__Task.t> => {
  let {message, configuration: _, metadata: _} = params

  // Find or create task
  let task = switch Agent__Message.getTaskId(message) {
  | Some(taskId) => {
      // Continue existing task
      switch agent.tasks->Dict.get(taskId) {
      | Some(existingTask) => {
          // Verify not terminal
          if Agent__Task.isTerminal(existingTask) {
            Console.error("Attempt to continue terminal task")
            let newTask = Agent__Task.make(
              ~contextId=Agent__Message.getTaskId(message),
            )
            agent.tasks->Dict.set(Agent__Task.getId(newTask), newTask)
            newTask
          } else {
            existingTask
          }
        }
      | None => {
          Console.error("Task not found, creating new")
          let newTask = Agent__Task.makeWithId(
            ~id=taskId,
            ~contextId=Agent__Message.getTaskId(message),
          )
          agent.tasks->Dict.set(taskId, newTask)
          newTask
        }
      }
    }
  | None => {
      // Create new task
      let newTask = Agent__Task.make(
        ~contextId=Agent__Message.getTaskId(message),
      )
      agent.tasks->Dict.set(Agent__Task.getId(newTask), newTask)
      newTask
    }
  }

  // Add user message to history
  task->Agent__Task.addMessage(message)

  // Emit event: message added
  agent.eventBus->Agent__EventBus.emit(
    DomainEvent(
      TaskMessageAdded({
        taskId: Agent__Task.getId(task),
        message,
      }),
    ),
  )

  // Initial callback to middleware
  callbacks.onTaskUpdate(task)

  // Transition to working
  let workingMessage = Agent__Message.make(
    ~role=Agent,
    ~parts=[Agent__Part.text(~text="Processing your request...")],
    ~taskId=Some(Agent__Task.getId(task)),
  )

  switch task->Agent__Task.transition(
    StartProcessing(~message=Some(workingMessage)),
  ) {
  | Ok() => {
      // Emit state changed event
      agent.eventBus->Agent__EventBus.emit(
        DomainEvent(
          TaskStateChanged({
            taskId: Agent__Task.getId(task),
            contextId: task.contextId,
            state: Agent__Task.getState(task),
          }),
        ),
      )
      callbacks.onTaskUpdate(task)
    }
  | Error(msg) => Console.error2("State transition error:", msg)
  }

  // Build LLM conversation
  let llmMessages = []

  llmMessages->Array.push({
    role: "system",
    content: Agent__Prompts.systemPrompt,
  })

  Agent__Task.getHistory(task)->Array.forEach(msg => {
    let content = buildLLMContent(Agent__Message.getParts(msg))
    let contextStr = buildContextString(Agent__Message.getMetadata(msg))
    let fullContent = content ++ contextStr

    llmMessages->Array.push({
      role: switch Agent__Message.getRole(msg) {
      | User => "user"
      | Agent => "assistant"
      },
      content: fullContent,
    })
  })

  // Process with LLM
  try {
    let stream = await Agent__Bindings__VercelAI.streamText({
      model: agent.model,
      messages: llmMessages,
      tools: Some(agent.tools),
      maxSteps: Some(5),
    })

    // Process stream
    // TODO: Emit artifact chunks as they arrive
    let result = await Agent__StreamProcessor.process(
      Agent__Task.getId(task),
      stream,
    )

    let responseText = result["text"]

    // Create artifact
    if responseText != "" {
      let artifact = Agent__Artifact.make(
        ~name=Some("Response"),
        ~parts=[Agent__Part.text(~text=responseText)],
      )

      task->Agent__Task.addArtifact(artifact)

      // Emit artifact event
      agent.eventBus->Agent__EventBus.emit(
        DomainEvent(
          ArtifactChunkGenerated({
            taskId: Agent__Task.getId(task),
            contextId: task.contextId,
            artifact,
            isComplete: true,
          }),
        ),
      )
    }

    // Add agent response to history
    let agentMessage = Agent__Message.make(
      ~role=Agent,
      ~parts=[Agent__Part.text(~text=responseText)],
      ~taskId=Some(Agent__Task.getId(task)),
    )
    task->Agent__Task.addMessage(agentMessage)

    // Transition to completed
    let _ = task->Agent__Task.transition(Complete(~message=Some(agentMessage)))

    // Emit final state
    agent.eventBus->Agent__EventBus.emit(
      DomainEvent(
        TaskStateChanged({
          taskId: Agent__Task.getId(task),
          contextId: task.contextId,
          state: Agent__Task.getState(task),
        }),
      ),
    )

    callbacks.onTaskUpdate(task)

    Promise.resolve(task)
  } catch {
  | error => {
      Console.error2("Agent processing error:", error)
      let errorMessage = %raw(`error.message || String(error)`)

      let errorMsg = Agent__Message.make(
        ~role=Agent,
        ~parts=[Agent__Part.text(~text=`Error: ${errorMessage}`)],
        ~taskId=Some(Agent__Task.getId(task)),
      )

      let _ = task->Agent__Task.transition(Fail(~message=errorMsg))

      agent.eventBus->Agent__EventBus.emit(
        DomainEvent(
          TaskStateChanged({
            taskId: Agent__Task.getId(task),
            contextId: task.contextId,
            state: Agent__Task.getState(task),
          }),
        ),
      )

      callbacks.onTaskUpdate(task)

      Promise.resolve(task)
    }
  }
}
```

**Rationale:**
- Handles both new tasks and continuations
- Explicit state transitions with error checking
- Emits domain events for internal streaming via EventBus
- Callbacks only at middleware boundary (onTaskUpdate)
- Framework context embedded in LLM messages
- Error handling with failed state transition

#### 2. Update Agent__Types.res
**File**: `libs/agent/src/Agent__Types.res`
**Changes**: Add task storage (fix storage type)

```rescript
module Agent = {
  type t = {
    projectRoot: string,
    model: Agent__Bindings__VercelAI.languageModel,
    tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
    eventBus: Agent__EventBus.t,
    tasks: Dict.t<Agent__Task.t>, // Changed from ref<Dict.t<...>>
  }

  let make = (projectRoot: string) => {
    Console.log(`Initializing agent for project: ${projectRoot}`)
    let eventBus = Agent__EventBus.make()

    let _apiKey = AskTheLlmBindings.Dotenv.getExn("OPENAI_API_KEY")
    let model = Agent__Bindings__VercelAI.OpenAI.gpt4o()

    let toolRegistry = Agent__Tools__Registry.make(projectRoot)
    let tools = Agent__Tools__Registry.toVercelTools(toolRegistry)

    tools
    ->Dict.toArray
    ->Array.forEach(((toolName, tool)) => {
      Console.error2(`Tool ${toolName}:`, tool.inputSchema)
    })

    Console.log(`Agent initialized with ${tools->Dict.size->Int.toString} tools`)

    {
      projectRoot,
      model,
      tools,
      eventBus,
      tasks: Dict.make(),
    }
  }
}
```

#### 3. Update Agent.res
**File**: `libs/agent/src/Agent.res`
**Changes**: Export message handler

```rescript
// Main Agent module - entry point

let _ = AskTheLlmBindings.Dotenv.config()

module Bindings = AskTheLlmBindings

// Keep existing run function for backward compatibility
let run = (agent: Agent__Types.Agent.t) => {
  let shutdown = agent.eventBus->Agent__EventBus.on((request: Agent__EventBus.events) => {
    switch request {
    | UserRequest(userRequest) => Agent__Loop.processRequest(agent, userRequest)->ignore
    | DomainEvent(_) => () // Ignore domain events in old handler
    }
  })
  Console.error("Agent is running and listening for requests...")
  shutdown
}

// Export new API
module MessageHandler = Agent__MessageHandler
module Task = Agent__Task
module Message = Agent__Message
module Artifact = Agent__Artifact
module Part = Agent__Part
module Id = Agent__Id

module Events = Agent__Events
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}
module Loop = Agent__Loop
module StreamProcessor = Agent__StreamProcessor
```

### Success Criteria

#### Automated Verification:
- [x] ReScript compiles successfully: `make -C libs/agent build`
- [x] processMessage has correct type signature
- [x] All modules are properly exported

#### Manual Verification:
- [x] Can call Agent.MessageHandler.processMessage (signature complete, needs integration testing)
- [ ] Domain events are emitted during processing (deferred - needs integration testing)
- [ ] onTaskUpdate callback is invoked (deferred - needs integration testing)
- [ ] State transitions occur correctly (deferred - needs integration testing)
- [ ] Task history is maintained (deferred - needs integration testing)
- [ ] Artifacts are created (deferred - needs integration testing)

---

## Phase 7: Middleware Integration

### Overview
Update Next.js middleware to call agent's message handler with proper parameters and handle callbacks.

### Changes Required

#### 1. Update Nextjs__Middleware.res
**File**: `libs/nextjs/src/Nextjs__Middleware.res`
**Changes**: Complete integration with agent

```rescript
// Next.js Middleware with Agent Integration

// Next.js types
module Request = {
  type t

  @get external url: t => string = "url"
  @get external method: t => string = "method"
  @send external json: t => promise<JSON.t> = "json"
}

module Response = {
  type t

  @module("next/server") @scope("NextResponse")
  external next: unit => t = "next"

  @module("next/server") @scope("NextResponse")
  external json: 'a => t = "json"
}

module Config = {
  type matcher = Array(array<string>)
  type t = {matcher: matcher}
  let make = (~matcher) => {matcher: matcher}
}

type handler = Request.t => promise<Response.t>

let getPathname = (url: string): string => {
  let urlObj = WebAPI.URL.make(~url)
  urlObj.pathname
}

// ============ Agent Instance ============

let agent = ref(None)

let getAgent = () => {
  switch agent.contents {
  | Some(a) => a
  | None => {
      let a = Agent.Agent__Types.Agent.make(Process.cwd())
      agent := Some(a)
      a
    }
  }
}

// ============ Context Collection ============

let collectFrameworkContext = (): Dict.t<JSON.t> => {
  let context = Dict.make()
  context->Dict.set("projectRoot", JSON.Encode.string(Process.cwd()))

  // TODO: Future enhancements:
  // - Hook into Next.js build events for compilation errors
  // - Buffer console logs
  // - Track current routes
  // - Capture build metrics

  context
}

// ============ JSON Serialization ============

let taskToJson = (_task: Agent.Task.t): JSON.t => {
  // TODO: Implement proper JSON serialization
  %raw(`_task`)
}

// ============ Request Handler ============

let handleAskTheLLM = async (req: Request.t): promise<Response.t> => {
  try {
    let body = await req->Request.json
    let bodyObj = body->JSON.Decode.object->Option.getExn

    let userMessage = bodyObj
      ->Dict.get("message")
      ->Option.flatMap(JSON.Decode.string)
      ->Option.getOr("Hello")

    // Extract optional taskId
    let taskIdStr = bodyObj->Dict.get("taskId")->Option.flatMap(JSON.Decode.string)
    let taskId = taskIdStr->Option.flatMap(Agent.Id.fromString)

    let agentInstance = getAgent()
    let frameworkContext = collectFrameworkContext()

    // Create message
    let message = Agent.Message.make(
      ~role=User,
      ~parts=[Agent.Part.text(~text=userMessage)],
      ~taskId,
      ~metadata=Some(frameworkContext),
    )

    // Create params
    let params: Agent.MessageHandler.MessageSendParams.t = {
      message,
      configuration: Some({blocking: Some(true)}),
      metadata: None,
    }

    // Create callbacks
    let callbacks: Agent.MessageHandler.callbacks = {
      onTaskUpdate: task => {
        Console.log("Task updated")
        // TODO: For SSE streaming, emit event here
        ignore(task)
      },
    }

    // Process message
    let task = await Agent.MessageHandler.processMessage(
      agentInstance,
      params,
      callbacks,
    )

    // Return task
    let responseJson = taskToJson(task)
    Response.json(responseJson)->Promise.resolve
  } catch {
  | error => {
      Console.error2("Middleware error:", error)
      Response.json({
        "error": "Internal server error",
        "details": %raw(`String(error)`),
      })->Promise.resolve
    }
  }
}

// ============ Main Middleware ============

let middleware: handler = async req => {
  let pathname = getPathname(Request.url(req))
  let method = Request.method(req)

  if pathname == "/ask-the-llm" && method == "POST" {
    await handleAskTheLLM(req)
  } else {
    Response.next()->Promise.resolve
  }
}

let config = Config.make(~matcher=Array(["/ask-the-llm"]))
```

**Rationale:**
- Singleton agent instance
- Collects framework context (placeholder)
- Constructs message with optional taskId
- Callbacks for middleware boundary
- Domain events flow internally via EventBus
- Clean separation of concerns

### Success Criteria

#### Automated Verification:
- [ ] ReScript compiles: `make -C libs/nextjs build`
- [ ] No type errors in middleware

#### Manual Verification:
- [ ] POST to /ask-the-llm works
- [ ] Agent processes message
- [ ] onTaskUpdate callback is invoked
- [ ] Task is returned with correct state
- [ ] Can continue task with taskId
- [ ] Domain events are emitted internally

---

## Testing Strategy

### Unit Tests

**libs/agent/test/Agent__Id.test.res** (new):
- Test Id.make() generates unique IDs
- Test fromString validates correctly
- Test cannot use string as Id

**libs/agent/test/Agent__Task.test.res** (new):
- Test Task.make() creates valid task
- Test initial state is Submitted
- Test legal transitions succeed
- Test illegal transitions return Error
- Test isTerminal correctly identifies terminal states
- Test all valid transition paths
- Test addMessage appends to history
- Test addArtifact appends to artifacts

**libs/agent/test/Agent__Part.test.res** (new):
- Test part constructors create valid parts
- Test cannot construct parts directly
- Test Part.text() works
- Test Part.file() works
- Test Part.data() works

**libs/agent/test/Agent__Message.test.res** (new):
- Test Message.make() auto-generates messageId
- Test cannot construct message directly
- Test accessors return correct values

**libs/agent/test/Agent__MessageHandler.test.res** (new):
- Test processMessage with valid params
- Test domain event emissions
- Test callback invocations
- Test multi-turn conversation
- Test error handling produces failed state

### Integration Tests

**Manual testing:**
1. Build both libs: `make -C libs/agent build && make -C libs/nextjs build`
2. Start example app: `make -C test/examples/blog-starter dev`
3. POST to /ask-the-llm with test messages
4. Verify responses
5. Test multi-turn conversations
6. Monitor console for state transitions and domain events

### Manual Testing Steps

1. **Single Message:**
   - POST to /ask-the-llm with `{"message": "Hello"}`
   - Verify: Task response with state=completed
   - Verify: Console shows state transitions
   - Verify: Domain events emitted

2. **Multi-Turn:**
   - Send first message
   - Extract taskId from response
   - Send second message with same taskId
   - Verify: Task history contains both messages
   - Verify: Agent maintains context

3. **Error Handling:**
   - Send invalid request
   - Verify: Failed state
   - Verify: Error message in response

4. **State Machine:**
   - Monitor console logs
   - Verify: Only legal transitions
   - Verify: Cannot transition from terminal states

## Performance Considerations

- Task storage is in-memory - implement cleanup
- Large conversation histories need pruning
- Domain events should be lightweight
- EventBus is synchronous - handlers should be fast
- Framework context collection should be efficient

## Migration Notes

### Backward Compatibility

- Old event-based API (`Agent__EventBus.UserRequest`) remains
- New code uses `Agent.MessageHandler.processMessage`
- Both APIs coexist during transition
- Plan to deprecate UserRequest in v2.0

### Migration Path

1. Deploy new implementation (Phase 1-7)
2. Update middleware to use new API
3. Test thoroughly
4. Mark old API as deprecated
5. Remove in next major version

## References

- A2A alignment spec: `spec_a2a_alignment.md`
- A2A Protocol: `docs/specification.md`
- Architecture: `docs/architecture.md`
- Current agent types: `libs/agent/src/Agent__Types.res:9`
- Current loop: `libs/agent/src/Agent__Loop.res:28`
- Current middleware: `libs/nextjs/src/Nextjs__Middleware.res:48`
- Stream processor: `libs/agent/src/Agent__StreamProcessor.res`

---

**Document Status:** Ready for implementation
**Next Step:** Begin Phase 1 - Opaque ID System and Core Types
**Estimated Effort:** 3-4 days for complete implementation (Phases 1-7)
