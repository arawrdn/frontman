---
date: 2025-10-15T19:18:39+0000
researcher: BlueHotDog
git_commit: fdb3153745f7188d021c29f01f81801700a34a7e
branch: main
repository: ask-the-llm
topic: "Task Lifecycle in libs/agent/ vs A2A Specification"
tags: [research, codebase, agent, task, state-machine, a2a-protocol]
status: complete
last_updated: 2025-10-15
last_updated_by: BlueHotDog
---

# Research: Task Lifecycle in libs/agent/ vs A2A Specification

**Date**: 2025-10-15T19:18:39+0000
**Researcher**: BlueHotDog
**Git Commit**: fdb3153745f7188d021c29f01f81801700a34a7e
**Branch**: main
**Repository**: ask-the-llm

## Research Question

How does the lifecycle of Tasks look like in @libs/agent/ and how does it compare to @docs/specification.md?

## Summary

The Task implementation in `libs/agent/` implements a type-safe finite state machine with six states, while the A2A specification defines eight task states. Both share core states (submitted, working, input-required, completed, failed, rejected) but differ in implementation approach and completeness.

**Key Differences**:
- **Missing States**: Implementation lacks `canceled` state present in A2A spec
- **Architecture**: Implementation uses ADT (Algebraic Data Type) state machine with compile-time validation; A2A uses object-based status model
- **Type Safety**: Implementation enforces required messages at type level; A2A allows optional messages in all states
- **Mutability**: Implementation uses ReScript `ref<>` for controlled mutability; A2A implies immutable snapshots
- **Timestamp Location**: Implementation stores timestamps per-state; A2A stores timestamp in TaskStatus object
- **History Requirement**: Implementation always maintains history array; A2A makes history optional

## Detailed Findings

### Current Implementation Architecture

#### Core Task Entity
**Location**: `libs/agent/src/Agent__Task.res:130-137`

The Task entity structure:
```rescript
type t = {
  id: Agent__Id.t,                           // Unique task ID
  contextId: option<Agent__Id.t>,            // Optional conversation context
  state: ref<State.t>,                       // Mutable state reference
  history: ref<array<Agent__Message.t>>,     // Mutable message history (always present)
  artifacts: ref<array<Agent__Artifact.t>>,  // Mutable artifacts
  metadata: option<Dict.t<JSON.t>>,          // Optional metadata
}
```

**Key Characteristics**:
- Uses `ref<>` for controlled mutability (ReScript convention)
- State stored as reference to immutable state variants
- History and artifacts grow monotonically via `Array.push()`
- IDs are opaque types (`Agent__Id.t`) for type safety
- **History is always present** (empty array at minimum)

#### State Machine Implementation

**Location**: `libs/agent/src/Agent__Task.res:20-126`

**Six States** (with distinct types):

1. **Submitted** (`libs/agent/src/Agent__Task.res:22-24`)
   - Initial state when task created
   - Contains only timestamp
   - No associated message

2. **Working** (`libs/agent/src/Agent__Task.res:26-29`)
   - Task actively processing
   - Optional message for status updates
   - Timestamp marks processing start

3. **InputRequired** (`libs/agent/src/Agent__Task.res:31-34`)
   - Task needs user input to proceed
   - **Required** message (enforced at type level)
   - Timestamp marks when input requested

4. **Completed** (`libs/agent/src/Agent__Task.res:36-39`)
   - Terminal state for successful completion
   - Optional message for final response
   - Timestamp marks completion

5. **Failed** (`libs/agent/src/Agent__Task.res:41-44`)
   - Terminal state for errors
   - **Required** message with error details
   - Timestamp marks failure

6. **Rejected** (`libs/agent/src/Agent__Task.res:46-49`)
   - Terminal state for rejected tasks
   - **Required** message with rejection reason
   - Timestamp marks rejection

**State Union** (`libs/agent/src/Agent__Task.res:52-58`):
```rescript
type t =
  | Submitted(submitted)
  | Working(working)
  | InputRequired(inputRequired)
  | Completed(completed)
  | Failed(failed)
  | Rejected(rejected)
```

**Timestamp per State**: Each state contains its own `timestamp: Timestamp.t` field.

#### State Transition Rules

**Location**: `libs/agent/src/Agent__Task.res:70-100`

**Legal Transitions**:

From **Submitted**:
- `StartProcessing` → `Working`
- `Reject` → `Rejected`

From **Working**:
- `Complete` → `Completed`
- `RequestInput` → `InputRequired`
- `Fail` → `Failed`

From **InputRequired**:
- `Resume` → `Working`
- `Fail` → `Failed`

**Terminal States** (no transitions allowed):
- `Completed`
- `Failed`
- `Rejected`

**Validation**:
```rescript
let transition = (current: t, event: event): result<t, string> => {
  switch (current, event) {
  | (Submitted(_), StartProcessing(message)) => Ok(Working({...}))
  | (Completed(_), _) => Error("Cannot transition from completed state")
  // ... other transitions
  | (_, _) => Error("Illegal state transition")
  }
}
```

Returns `result<t, string>` for explicit error handling at compile time.

#### Event System

**Location**: `libs/agent/src/Agent__EventBus.res:1-43`

**Three Event Types**:

1. **TaskStateChanged** (`libs/agent/src/Agent__EventBus.res:1-4`)
   ```rescript
   type taskStateChanged = {
     taskId: Agent__Id.t,
     contextId: option<Agent__Id.t>,
   }
   ```

2. **ArtifactChunkGenerated** (`libs/agent/src/Agent__EventBus.res:6-11`)
   ```rescript
   type artifactChunkGenerated = {
     taskId: Agent__Id.t,
     contextId: option<Agent__Id.t>,
     artifact: Agent__Artifact.t,
     isComplete: bool,
   }
   ```

3. **TaskMessageAdded** (`libs/agent/src/Agent__EventBus.res:13-16`)
   ```rescript
   type taskMessageAdded = {
     taskId: Agent__Id.t,
     message: Agent__Message.t,
   }
   ```

**EventBus Implementation** (`libs/agent/src/Agent__EventBus.res:23-43`):
- Simple pub/sub pattern with handler array
- `emit()` broadcasts to all handlers
- `on()` returns unsubscribe function

#### Task Lifecycle in Practice

**Location**: `libs/agent/src/Agent__MessageHandler.res:10-122`

**Complete Flow**:

1. **Task Creation/Retrieval** (lines 19-33):
   ```rescript
   let task = switch taskId {
   | Some(id) => tasks->Dict.get(Agent__Id.toString(id))
   | None => Agent__Task.make(~contextId)
   }
   ```

2. **Add User Message** (line 36):
   ```rescript
   task->Agent__Task.addMessage(userMessage)
   ```

3. **Transition to Working** (lines 39-45):
   ```rescript
   let _ = switch task->Agent__Task.getState {
   | Submitted(_) => task->Agent__Task.transition(StartProcessing(None))
   | InputRequired(_) => task->Agent__Task.transition(Resume(None))
   | _ => Ok()
   }
   ```

4. **Emit State Changed Event** (lines 48-53):
   ```rescript
   agent.eventBus->Agent__EventBus.emit(
     TaskStateChanged({taskId: task.id, contextId: task.contextId})
   )
   ```

5. **Process with LLM** (line 64):
   ```rescript
   let response = await llm->Agent__LLM.chat(history)
   ```

6. **Add Agent Response** (lines 67-75):
   ```rescript
   let agentMessage = Agent__Message.make(~role=Agent, ~parts=[...])
   task->Agent__Task.addMessage(agentMessage)
   ```

7. **Emit Message Added** (lines 78-83):
   ```rescript
   agent.eventBus->Agent__EventBus.emit(
     TaskMessageAdded({taskId: task.id, message: agentMessage})
   )
   ```

8. **Complete Task** (line 86):
   ```rescript
   let _ = task->Agent__Task.transition(Complete(Some(agentMessage)))
   ```

9. **Emit Final State** (lines 89-94):
   ```rescript
   agent.eventBus->Agent__EventBus.emit(
     TaskStateChanged({taskId: task.id, contextId: task.contextId})
   )
   ```

**Error Handling** (lines 99-117):
```rescript
catch {
| error =>
  let errorMessage = Agent__Message.make(~role=Agent, ...)
  let _ = task->Agent__Task.transition(Fail(errorMessage))
  agent.eventBus->Agent__EventBus.emit(TaskStateChanged({...}))
}
```

### A2A Specification Overview

**Source**: `/Users/danni/dev/ask-the-llm/docs/specification.md`

#### Task Object Structure (Section 6.1)

A2A defines Task as:
```typescript
{
  id: string,                        // Unique task ID
  contextId?: string,                // Optional context grouping
  status: TaskStatus,                // Current status object
  artifacts?: Artifact[],            // Generated outputs
  history?: Message[],               // Message history (OPTIONAL)
  metadata?: Record<string, any>     // Extension metadata
}
```

**Key Point**: History is **optional** in A2A spec.

#### TaskStatus Object (Section 6.2)

```typescript
{
  state: TaskState,                  // Current state enum
  message?: Message,                 // Optional status message
  timestamp: string                  // ISO 8601 timestamp (at status level)
}
```

**Key Difference**:
- Status is a separate object containing state
- **Timestamp is in TaskStatus object**, not in each state
- Message is always optional

#### TaskState Enum (Section 6.3)

**Eight States** defined in A2A:
1. `submitted` - Initial state
2. `working` - Processing in progress
3. `input-required` - Needs user input
4. `completed` - Successfully finished
5. `canceled` - User or system canceled ⚠️ **Not in implementation**
6. `failed` - Error occurred
7. `rejected` - Rejected before processing

#### State Transitions (Section 6.1, 7.1, 7.2)

A2A describes transitions primarily through method calls:
- `message/send` or `message/stream` can create or update tasks
- Tasks in terminal states (`completed`, `canceled`, `failed`, `rejected`) cannot accept new messages
- Spec states: "A task which has reached a terminal state cannot be restarted"

**No explicit state machine** is defined in the spec, but transitions are implied through method descriptions and workflow examples (Section 9).

### Comparison: Implementation vs Specification

#### States Alignment

| A2A Spec State | Implementation State | Status |
|----------------|---------------------|--------|
| `submitted` | `Submitted` | ✅ Matches |
| `working` | `Working` | ✅ Matches |
| `input-required` | `InputRequired` | ✅ Matches |
| `completed` | `Completed` | ✅ Matches |
| `canceled` | — | ❌ Missing |
| `failed` | `Failed` | ✅ Matches |
| `rejected` | `Rejected` | ✅ Matches |

**Coverage**: 6/7 relevant states implemented (86%)

#### Missing State

**`canceled`** (A2A Section 7.4):
- Purpose: User or system canceled the task
- Use case: User cancels long-running operation
- Method: `tasks/cancel` RPC method
- Implementation gap: No cancel state or cancellation support

#### Architectural Differences

**1. State Representation**

| Aspect | Implementation | A2A Spec |
|--------|---------------|----------|
| Model | ADT (Algebraic Data Type) | Enum string |
| Structure | Each state = distinct type | Single state field in status |
| Validation | Compile-time pattern matching | Runtime checks |
| **Timestamp** | **Per-state field** | **In TaskStatus object** |
| Message | Type-enforced (required/optional) | Always optional |

**Implementation**: Each state has `timestamp: Timestamp.t` field
**A2A**: `TaskStatus` object has single `timestamp: string` field

**2. TaskStatus Object**

| Implementation | A2A Spec |
|---------------|----------|
| State stored directly as ADT | State wrapped in TaskStatus object |
| No TaskStatus abstraction | TaskStatus = {state, message?, timestamp} |
| Timestamp per state | Timestamp in status |
| Message in state (typed) | Message in status (always optional) |

**A2A Structure**:
```typescript
{
  id: "task-123",
  status: {
    state: "working",
    message: {...},      // optional
    timestamp: "2025-10-15T19:18:39Z"
  }
}
```

**Implementation Structure**:
```rescript
{
  id: Id("task-123"),
  state: ref(Working({
    timestamp: Timestamp("2025-10-15T19:18:39Z"),
    message: Some({...})
  }))
}
```

**3. History Requirement**

| Aspect | Implementation | A2A Spec |
|--------|---------------|----------|
| History field | Always present (`ref<array<Message>>`) | Optional (`history?: Message[]`) |
| Initial value | Empty array `[]` | Can be absent |
| Usage | Always tracked | Optional feature |

**Implementation** (`libs/agent/src/Agent__Task.res:145`):
```rescript
history: ref([]),  // Always initialized
```

**A2A**: History is optional, may not be included in Task object.

**4. State Transitions**

| Aspect | Implementation | A2A Spec |
|--------|---------------|----------|
| Definition | Explicit state machine with transition function | Implicit through method constraints |
| Validation | `result<t, string>` with error messages | Method-level errors |
| Events | Six explicit event types | Not specified in detail |
| Enforcement | Compile-time + runtime | Runtime only |

**Implementation**: `libs/agent/src/Agent__Task.res:60-100`
- Events: `StartProcessing`, `RequestInput`, `Resume`, `Complete`, `Fail`, `Reject`
- Returns: `result<State.t, string>`
- Errors: "Cannot transition from X state", "Illegal state transition"

**A2A Spec**: Section 7.1, 7.2
- Terminal tasks cannot receive messages
- Methods return JSON-RPC errors for invalid operations
- No explicit transition rules defined

**5. Mutability Model**

| Aspect | Implementation | A2A Spec |
|--------|---------------|----------|
| State | `ref<State.t>` (mutable reference to immutable state) | Not specified |
| History | `ref<array<Message>>` (mutable array, always present) | `Message[]?` (optional, implied immutable) |
| Artifacts | `ref<array<Artifact>>` (mutable array) | `Artifact[]?` (optional, implied immutable) |
| Updates | In-place mutation via `:=` and `Array.push()` | Task snapshot updates |

**Implementation Pattern** (`libs/agent/src/Agent__Task.res:163-171`):
```rescript
let transition = (task: t, event: State.event): result<unit, string> => {
  switch State.transition(task.state.contents, event) {
  | Ok(newState) => {
      task.state := newState  // Mutate ref
      Ok()
    }
  | Error(msg) => Error(msg)
  }
}
```

**A2A Pattern**: Methods return updated Task object (e.g., `message/send` returns `Task`)

**6. Message Requirements**

| State | Implementation | A2A Spec |
|-------|---------------|----------|
| Submitted | No message (type-level) | Optional message |
| Working | Optional message | Optional message |
| InputRequired | **Required** message | Optional message |
| Completed | Optional message | Optional message |
| Failed | **Required** message | Optional message |
| Rejected | **Required** message | Optional message |

**Implementation Advantage**: Type system prevents creating `InputRequired` state without a question, or `Failed` state without error details.

**A2A Spec** (Section 6.2): `TaskStatus.message` is always `message?: Message` (optional).

#### Data Structure Alignment

**Task Entity**:

| Field | Implementation | A2A Spec | Match |
|-------|---------------|----------|-------|
| `id` | `Agent__Id.t` (opaque UUID) | `string` | ✅ Compatible |
| `contextId` | `option<Agent__Id.t>` | `string?` | ✅ Matches |
| `state` / `status` | `ref<State.t>` with timestamp per state | `TaskStatus` with single timestamp | ⚠️ Different structure |
| `history` | `ref<array<Message>>` (always present) | `Message[]?` (optional) | ⚠️ Always present vs optional |
| `artifacts` | `ref<array<Artifact>>` | `Artifact[]?` | ✅ Compatible |
| `metadata` | `option<Dict.t<JSON.t>>` | `Record<string, any>?` | ✅ Compatible |

**Key Differences**:
1. Implementation stores state directly as ADT; A2A wraps in TaskStatus with timestamp and optional message
2. Implementation always has history array; A2A makes history optional

**Message Entity**:

Both use similar structure:
- `role` (User/Agent vs "user"/"agent")
- `parts` (array of content parts)
- `messageId` (UUID)
- `taskId`, `contextId` (optional links)

**Artifact Entity**:

Both use:
- `artifactId` (UUID)
- `parts` (array of content parts)
- `name` (optional)
- `metadata` (optional)

#### Lifecycle Flow Comparison

**Implementation Flow** (`libs/agent/src/Agent__MessageHandler.res`):
```
1. Create/retrieve task (Submitted state)
2. Add user message to history
3. Transition: Submitted → Working
4. Emit TaskStateChanged event
5. Process with LLM
6. Add agent message to history
7. Emit TaskMessageAdded event
8. Transition: Working → Completed (or Failed)
9. Emit TaskStateChanged event
```

**A2A Flow** (Section 9.2, 9.3):
```
1. Client sends message/send or message/stream
2. Server creates Task (submitted state)
3. Server transitions to working
4. Server processes request
5. Server transitions to completed/failed
6. Server sends final Task object
```

**Similarities**:
- Both start in submitted
- Both transition to working
- Both emit updates during processing
- Both end in terminal state (completed/failed)

**Differences**:
- Implementation always maintains history; A2A allows tasks without history
- Implementation has timestamps per-state; A2A has single timestamp in TaskStatus

### Code References

**Core Implementation**:
- `libs/agent/src/Agent__Task.res:1-188` - Complete Task module
- `libs/agent/src/Agent__Task.res:20-126` - State machine definition
- `libs/agent/src/Agent__Task.res:130-160` - Task entity and constructors
- `libs/agent/src/Agent__Task.res:163-171` - State transition handler

**State Definitions**:
- `libs/agent/src/Agent__Task.res:22-24` - Submitted state (timestamp only)
- `libs/agent/src/Agent__Task.res:26-29` - Working state (timestamp + optional message)
- `libs/agent/src/Agent__Task.res:31-34` - InputRequired state (timestamp + required message)
- `libs/agent/src/Agent__Task.res:36-39` - Completed state (timestamp + optional message)
- `libs/agent/src/Agent__Task.res:41-44` - Failed state (timestamp + required message)
- `libs/agent/src/Agent__Task.res:46-49` - Rejected state (timestamp + required message)

**Transition Rules**:
- `libs/agent/src/Agent__Task.res:70-100` - Legal transitions definition
- `libs/agent/src/Agent__Task.res:103-108` - Terminal state checker

**Usage Patterns**:
- `libs/agent/src/Agent__MessageHandler.res:10-122` - Complete lifecycle example
- `libs/agent/src/Agent__MessageHandler.res:19-33` - Task retrieval/creation
- `libs/agent/src/Agent__MessageHandler.res:39-45` - State transitions in practice
- `libs/agent/src/Agent__MessageHandler.res:86` - Task completion
- `libs/agent/src/Agent__MessageHandler.res:108` - Task failure

**Event System**:
- `libs/agent/src/Agent__EventBus.res:1-43` - EventBus implementation
- `libs/agent/src/Agent__EventBus.res:1-4` - TaskStateChanged event
- `libs/agent/src/Agent__EventBus.res:6-11` - ArtifactChunkGenerated event
- `libs/agent/src/Agent__EventBus.res:13-16` - TaskMessageAdded event

**Supporting Modules**:
- `libs/agent/src/Agent__Message.res:14-29` - Message creation
- `libs/agent/src/Agent__Artifact.res:10-21` - Artifact creation
- `libs/agent/src/Agent__Id.res:5-7` - UUID generation

### State Transition Diagrams

#### Current Implementation

```
                    StartProcessing
    Submitted ─────────────────────────> Working
        │                                   │ │ │
        │                                   │ │ │
        │ Reject                  Complete  │ │ │ RequestInput
        │                                   │ │ │
        ↓                                   ↓ │ └──────────────> InputRequired
    Rejected                          Completed│                       │ │
   (terminal)                        (terminal)│ Fail                  │ │
                                               │                Resume │ │ Fail
                                               ↓                       │ │
                                            Failed <────────────────────┘ │
                                          (terminal)<───────────────────────┘
```

#### A2A Specification (Inferred)

```
                    message/send
    submitted ─────────────────────────> working
        │                                   │ │ │
        │                                   │ │ │
        │                                   │ │ │ message/send
        │                                   │ │ │ (input needed)
        ↓                                   │ │ └──────────────> input-required
    rejected                                │ │                       │ │
   (terminal)                               │ │                       │ │
                                            │ │            message/   │ │
                                  message/  │ │              send     │ │
                                    send    │ │           (resume)    │ │
                                 (complete) │ │                       │ │
                                            │ │                       ↓ │
                                            ↓ │                     working
                                        completed                      │
                                       (terminal)│                     │
                                                 │          error      │
                                   tasks/cancel  │                     │
                                    or error     │                     │
                                                 ↓                     ↓
                                             canceled               failed
                                            (terminal)             (terminal)
```

**Note**: A2A spec doesn't provide explicit state diagram; this is inferred from method descriptions and examples.

### Key Insights

#### Strengths of Current Implementation

1. **Type Safety**:
   - Compile-time validation of state transitions
   - Required messages enforced at type level
   - Impossible to access non-existent fields

2. **Explicit State Machine**:
   - Clear transition rules in code
   - Easy to understand all possible paths
   - Error messages for invalid transitions

3. **Event-Driven Architecture**:
   - Decoupled components via EventBus
   - Easy to add listeners for logging, metrics, etc.

4. **Immutable States**:
   - Each state is immutable record
   - Transitions create new states
   - History preserved via ref array

#### Alignment Gaps with A2A Spec

1. **Missing State**:
   - No `canceled` for task cancellation
   - No cancellation mechanism or event

2. **Timestamp Location**:
   - Implementation: Timestamp in each state variant
   - A2A: Timestamp in TaskStatus object
   - Need to refactor to single timestamp at task level

3. **TaskStatus Abstraction**:
   - Implementation: Direct state storage as ADT
   - A2A: TaskStatus wrapper object `{state, message?, timestamp}`
   - Need compatibility layer for A2A output

4. **History Requirement**:
   - Implementation: Always maintains history array
   - A2A: History is optional
   - Need to make history optional in Task type

### Alignment Requirements

To align implementation with A2A spec:

**1. Add Canceled State**:
```rescript
// In Agent__Task.res State module
type canceled = {
  timestamp: Timestamp.t,
  message: option<Agent__Message.t>,
}

type t =
  | Submitted(submitted)
  | Working(working)
  | InputRequired(inputRequired)
  | Completed(completed)
  | Canceled(canceled)  // New
  | Failed(failed)
  | Rejected(rejected)
```

**2. Add Cancel Event and Transitions**:
```rescript
type event =
  | StartProcessing(option<Agent__Message.t>)
  | RequestInput(Agent__Message.t)
  | Resume(option<Agent__Message.t>)
  | Cancel(option<Agent__Message.t>)  // New
  | Complete(option<Agent__Message.t>)
  | Fail(Agent__Message.t)
  | Reject(Agent__Message.t)

// Add transitions to Canceled from Working and InputRequired
| (Working(_), Cancel(message)) =>
  Ok(Canceled({timestamp: Timestamp.now(), message}))
| (InputRequired(_), Cancel(message)) =>
  Ok(Canceled({timestamp: Timestamp.now(), message}))
```

**3. Move Timestamp to Task Level**:

Change from per-state timestamps to single timestamp in Task entity matching A2A TaskStatus:

Current:
```rescript
type t = {
  id: Agent__Id.t,
  state: ref<State.t>,  // Each state has timestamp
  // ...
}
```

Aligned:
```rescript
type t = {
  id: Agent__Id.t,
  state: ref<State.t>,  // States no longer have timestamps
  timestamp: ref<Timestamp.t>,  // Single timestamp updated on transitions
  // ...
}
```

**4. Make History Optional**:

Current:
```rescript
type t = {
  // ...
  history: ref<array<Agent__Message.t>>,  // Always present
  // ...
}
```

Aligned:
```rescript
type t = {
  // ...
  history: option<ref<array<Agent__Message.t>>>,  // Optional like A2A
  // ...
}
```

**5. Add TaskStatus Compatibility**:

Add functions in `libs/agent/src/Agent.res` to convert internal state to A2A-compatible format:

```rescript
// In Agent.res
type taskStatus = {
  state: string,              // "submitted", "working", etc.
  message: option<Message.t>,
  timestamp: string,          // ISO 8601
}

let getTaskStatus = (task: Task.t): taskStatus => {
  {
    state: Task.stateToString(task.state.contents),
    message: Task.State.getMessage(task.state.contents),
    timestamp: task.timestamp.contents->Timestamp.toString,
  }
}

let getTask = (task: Task.t): task => {
  {
    id: Task.getId(task)->Id.toString,
    contextId: task.contextId->Option.map(Id.toString),
    status: getTaskStatus(task),
    artifacts: Some(Task.getArtifacts(task)),
    history: task.history->Option.map(h => h.contents),  // Optional
    metadata: task.metadata,
  }
}
```

This maintains type safety internally while providing A2A-compatible output through `libs/agent/src/Agent.res` functions.

## Open Questions

1. **Cancellation Trigger**: Should task cancellation be user-initiated only, or also support system-initiated cancellation (e.g., timeout)?

2. **History Optional Usage**: When should tasks be created without history? What use cases benefit from no history tracking?

3. **Timestamp Updates**: Should timestamp update on every state transition, or only on specific transitions?

4. **Terminal State for Canceled**: Should `canceled` be a terminal state like `completed`/`failed`/`rejected`?

5. **Message in Canceled**: Should canceled state require or allow an optional message explaining cancellation reason?

## Implementation Results (2025-10-15)

### Changes Implemented

**Phase 1: Canceled State**
- Added `Canceled` state variant to `State.t` union (libs/agent/src/Agent__Task.res:51-54)
- Added `Cancel` event to `State.event` (libs/agent/src/Agent__Task.res:74)
- Transitions from Submitted, Working, InputRequired → Canceled (libs/agent/src/Agent__Task.res:84-85, 94-95, 102-103)
- Canceled is terminal state (no outgoing transitions) (libs/agent/src/Agent__Task.res:109)
- Optional message field for cancellation reason

**Phase 2: TaskStatus Wrapper**
- Created TaskStatus module wrapping State: `{state, message, timestamp}` (libs/agent/src/Agent__Task.res:145-182)
- Task entity now has `status: ref<TaskStatus.t>` instead of `state: ref<State.t>` (libs/agent/src/Agent__Task.res:185)
- TaskStatus.timestamp updated on every transition (libs/agent/src/Agent__Task.res:179)
- Per-state timestamps preserved internally (extra detail for audit trail)
- Structure now matches A2A TaskStatus specification

**Alignment Achieved:**
- ✅ All 7 A2A states supported (7/7) - added Canceled
- ✅ TaskStatus structure matches A2A spec
- ✅ Single timestamp at TaskStatus level (A2A compatible)
- ✅ Per-state timestamps preserved (internal audit trail)
- ✅ History mandatory (simplified implementation)
- ✅ Full type safety maintained
- ✅ Backward compatible API (getState, transition, isTerminal unchanged)

**Structure Comparison:**

A2A Specification:
```typescript
{
  id: string,
  status: { state: TaskState, message?: Message, timestamp: string },
  history?: Message[],
  artifacts?: Artifact[],
}
```

Implementation:
```rescript
{
  id: Agent__Id.t,
  status: ref<{state: State.t, message: option<Message.t>, timestamp: Timestamp.t}>,
  history: ref<array<Message.t>>,  // mandatory, not optional
  artifacts: ref<array<Artifact.t>>,
}
```

**Differences (By Design):**
- History always present (vs optional in A2A)
- Per-state timestamps exist internally (richer audit trail)
- Refs for controlled mutability (vs immutable snapshots in A2A)

**API Compatibility:**
All existing code using Agent__Task continues to work:
- `getState()` - returns State.t (now extracts from status)
- `getStatus()` - NEW: returns full TaskStatus.t
- `transition()` - same signature and behavior
- `isTerminal()` - same behavior
- MessageHandler required no changes

---

**End of Research Document**
