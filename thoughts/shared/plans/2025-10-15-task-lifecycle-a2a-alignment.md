# Task Lifecycle A2A Alignment Implementation Plan

## Overview

This plan aligns the Task lifecycle implementation in `libs/agent/` with the A2A Protocol specification by adding the missing Canceled state and wrapping the state in a TaskStatus object. The internal per-state timestamps are preserved as "extra" internal detail - the core shape and function matches A2A.

## Current State Analysis

The current implementation (`libs/agent/src/Agent__Task.res`) provides:

### Strengths:
- **Type-safe finite state machine** with compile-time validation
- **Six states**: Submitted, Working, InputRequired, Completed, Failed, Rejected
- **Event-driven architecture** via EventBus
- **Always-present history** tracking all messages
- **Per-state timestamps** providing internal audit trail

### Gaps vs A2A:
- **Missing Canceled state** - A2A has 7 states
- **Direct state storage** - A2A wraps state in TaskStatus object
- **No TaskStatus.timestamp** - A2A has timestamp at TaskStatus level

### Key Code Locations:
- State machine: `libs/agent/src/Agent__Task.res:20-126`
- Task entity: `libs/agent/src/Agent__Task.res:130-137`
- State transitions: `libs/agent/src/Agent__Task.res:163-171`
- Message handler usage: `libs/agent/src/Agent__MessageHandler.res:10-122`

## Desired End State

After implementation, Task structure will be:

```rescript
type t = {
  id: Agent__Id.t,
  contextId: option<Agent__Id.t>,
  status: ref<TaskStatus.t>,        // NEW: wraps state + timestamp + message
  history: ref<array<Agent__Message.t>>,
  artifacts: ref<array<Agent__Artifact.t>>,
  metadata: option<Dict.t<JSON.t>>,
}

// TaskStatus matches A2A spec
module TaskStatus = {
  type t = {
    state: State.t,                 // State enum (still has internal timestamps)
    message: option<Agent__Message.t>,
    timestamp: Timestamp.t,         // A2A-visible timestamp
  }
}
```

**Key Point**: State variants keep their internal timestamps (for audit trail), but TaskStatus.timestamp is the "official" A2A timestamp that gets updated on transitions.

### Verification:
- Task.status.state matches A2A TaskStatus.state
- Task.status.timestamp matches A2A TaskStatus.timestamp
- Task.status.message matches A2A TaskStatus.message
- All 7 A2A states supported including Canceled

## What We're NOT Doing

- **NOT removing per-state timestamps** - they're extra internal detail
- **NOT making history optional** - keeping it mandatory
- **NOT changing event system** - EventBus unchanged
- **NOT implementing RPC methods** - only data structure changes
- **NOT adding serialization layer** - structure IS A2A-shaped

## Implementation Approach

**Two-phase approach**:
1. **Phase 1**: Add Canceled state to existing structure
2. **Phase 2**: Refactor to wrap state in TaskStatus

Each phase is independently testable and committable.

---

## Phase 1: Add Canceled State

### Overview
Adds the missing `canceled` state to achieve A2A state coverage. Terminal state reachable from any non-terminal state.

### Changes Required:

#### 1. State Type Definitions
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Add canceled state variant after rejected (around line 46)

```rescript
type rejected = {
  timestamp: Timestamp.t,
  message: Agent__Message.t,
}

type canceled = {
  timestamp: Timestamp.t,
  message: option<Agent__Message.t>, // Optional cancellation reason
}

// State union
type t =
  | Submitted(submitted)
  | Working(working)
  | InputRequired(inputRequired)
  | Completed(completed)
  | Failed(failed)
  | Rejected(rejected)
  | Canceled(canceled)  // NEW
```

#### 2. Event Type
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Add Cancel event (around line 60)

```rescript
type event =
  | StartProcessing(option<Agent__Message.t>)
  | RequestInput(Agent__Message.t)
  | Resume(option<Agent__Message.t>)
  | Complete(option<Agent__Message.t>)
  | Fail(Agent__Message.t)
  | Reject(Agent__Message.t)
  | Cancel(option<Agent__Message.t>)  // NEW
```

#### 3. Transition Rules
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Add cancel transitions from all non-terminal states (lines 70-100)

```rescript
let transition = (current: t, event: event): result<t, string> => {
  switch (current, event) {
  // From Submitted - add Cancel
  | (Submitted(_), StartProcessing(message)) =>
    Ok(Working({timestamp: Timestamp.now(), message}))
  | (Submitted(_), Reject(message)) =>
    Ok(Rejected({timestamp: Timestamp.now(), message}))
  | (Submitted(_), Cancel(message)) =>
    Ok(Canceled({timestamp: Timestamp.now(), message}))  // NEW

  // From Working - add Cancel
  | (Working(_), Complete(message)) =>
    Ok(Completed({timestamp: Timestamp.now(), message}))
  | (Working(_), RequestInput(message)) =>
    Ok(InputRequired({timestamp: Timestamp.now(), message}))
  | (Working(_), Fail(message)) =>
    Ok(Failed({timestamp: Timestamp.now(), message}))
  | (Working(_), Cancel(message)) =>
    Ok(Canceled({timestamp: Timestamp.now(), message}))  // NEW

  // From InputRequired - add Cancel
  | (InputRequired(_), Resume(message)) =>
    Ok(Working({timestamp: Timestamp.now(), message}))
  | (InputRequired(_), Fail(message)) =>
    Ok(Failed({timestamp: Timestamp.now(), message}))
  | (InputRequired(_), Cancel(message)) =>
    Ok(Canceled({timestamp: Timestamp.now(), message}))  // NEW

  // Terminal states
  | (Completed(_), _) => Error("Cannot transition from completed state")
  | (Failed(_), _) => Error("Cannot transition from failed state")
  | (Rejected(_), _) => Error("Cannot transition from rejected state")
  | (Canceled(_), _) => Error("Cannot transition from canceled state")  // NEW

  | (_, _) => Error("Illegal state transition")
  }
}
```

#### 4. Helper Functions
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Update isTerminal and getMessage (lines 103-125)

```rescript
let isTerminal = (state: t): bool => {
  switch state {
  | Completed(_) | Failed(_) | Rejected(_) | Canceled(_) => true  // Add Canceled
  | _ => false
  }
}

let getMessage = (state: t): option<Agent__Message.t> => {
  switch state {
  | Submitted(_) => None
  | Working({message}) => message
  | InputRequired({message}) => Some(message)
  | Completed({message}) => message
  | Failed({message}) => Some(message)
  | Rejected({message}) => Some(message)
  | Canceled({message}) => message  // NEW
  }
}
```

### Success Criteria:

#### Automated Verification:
- [x] Code compiles: `make -C libs/agent build`
- [x] Type checker validates exhaustive pattern matching
- [x] All existing tests pass: `make -C libs/agent test`

#### Manual Verification:
- [x] Can transition to Canceled from Submitted, Working, InputRequired
- [x] Cannot transition from Canceled to any state
- [x] Canceled state correctly stores optional message
- [x] isTerminal returns true for Canceled

---

## Phase 2: Wrap State in TaskStatus

### Overview
Refactors Task to use TaskStatus wrapper matching A2A specification. TaskStatus contains state + timestamp + message.

### Changes Required:

#### 1. TaskStatus Module
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Add TaskStatus module after State module (around line 127)

```rescript
// TaskStatus wrapper - matches A2A TaskStatus object
module TaskStatus = {
  type t = {
    state: State.t,
    message: option<Agent__Message.t>,
    timestamp: Timestamp.t,
  }

  // Create initial TaskStatus
  let make = (): t => {
    {
      state: State.initial(),
      message: None,
      timestamp: Timestamp.now(),
    }
  }

  // Create from state and message
  let fromState = (state: State.t, message: option<Agent__Message.t>): t => {
    {
      state,
      message,
      timestamp: Timestamp.now(),
    }
  }

  // Update with new state, preserving message or using new one
  let transition = (status: t, newState: State.t, newMessage: option<Agent__Message.t>): t => {
    {
      state: newState,
      message: newMessage->Option.or(State.getMessage(newState)),
      timestamp: Timestamp.now(),
    }
  }
}
```

#### 2. Task Entity Refactor
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Update Task type (lines 130-137)

```rescript
// OLD:
// type t = {
//   id: Agent__Id.t,
//   contextId: option<Agent__Id.t>,
//   state: ref<State.t>,
//   history: ref<array<Agent__Message.t>>,
//   artifacts: ref<array<Agent__Artifact.t>>,
//   metadata: option<Dict.t<JSON.t>>,
// }

// NEW:
type t = {
  id: Agent__Id.t,
  contextId: option<Agent__Id.t>,
  status: ref<TaskStatus.t>,  // Changed from state to status
  history: ref<array<Agent__Message.t>>,
  artifacts: ref<array<Agent__Artifact.t>>,
  metadata: option<Dict.t<JSON.t>>,
}
```

#### 3. Constructor Updates
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Update make functions (lines 140-160)

```rescript
let make = (~contextId=None, ~metadata=None): t => {
  {
    id: Agent__Id.make(),
    contextId,
    status: ref(TaskStatus.make()),  // Changed
    history: ref([]),
    artifacts: ref([]),
    metadata,
  }
}

let makeWithId = (~id, ~contextId=None, ~metadata=None): t => {
  {
    id,
    contextId,
    status: ref(TaskStatus.make()),  // Changed
    history: ref([]),
    artifacts: ref([]),
    metadata,
  }
}
```

#### 4. Transition Function Refactor
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Update transition to work with TaskStatus (lines 163-171)

```rescript
// OLD:
// let transition = (task: t, event: State.event): result<unit, string> => {
//   switch State.transition(task.state.contents, event) {
//   | Ok(newState) => {
//       task.state := newState
//       Ok()
//     }
//   | Error(msg) => Error(msg)
//   }
// }

// NEW:
let transition = (task: t, event: State.event): result<unit, string> => {
  let currentState = task.status.contents.state
  switch State.transition(currentState, event) {
  | Ok(newState) => {
      let message = State.getMessage(newState)
      task.status := TaskStatus.transition(task.status.contents, newState, message)
      Ok()
    }
  | Error(msg) => Error(msg)
  }
}
```

#### 5. Query Functions Update
**File**: `libs/agent/src/Agent__Task.res`
**Changes**: Update helper functions (lines 174-178)

```rescript
// Update these functions:
let isTerminal = (task: t): bool => State.isTerminal(task.status.contents.state)
let getState = (task: t): State.t => task.status.contents.state
let getStatus = (task: t): TaskStatus.t => task.status.contents  // NEW
let getId = (task: t): Agent__Id.t => task.id
let getHistory = (task: t): array<Agent__Message.t> => task.history.contents
let getArtifacts = (task: t): array<Agent__Artifact.t> => task.artifacts.contents
```

#### 6. MessageHandler Updates
**File**: `libs/agent/src/Agent__MessageHandler.res`
**Changes**: No changes needed! The API (`getState`, `transition`) works the same

Verify that:
- Line 39: `task->Agent__Task.getState` still works
- Line 86: `task->Agent__Task.transition(Complete(Some(agentMessage)))` still works
- Line 108: `task->Agent__Task.transition(Fail(errorMessage))` still works

### Success Criteria:

#### Automated Verification:
- [x] Code compiles: `make -C libs/agent build`
- [x] All tests pass: `make -C libs/agent test`
- [x] No changes needed in MessageHandler (API compatibility)

#### Manual Verification:
- [x] `task.status` contains state, message, timestamp
- [x] `task.status.timestamp` updates on each transition
- [x] `getState` returns State.t correctly
- [x] `getStatus` returns full TaskStatus.t
- [x] TaskStatus structure matches A2A TaskStatus object

---

## Phase 3: Testing

### Overview
Comprehensive tests for Canceled state and TaskStatus structure.

### Changes Required:

#### 1. Canceled State Tests
**File**: Create `libs/agent/test/Agent__Task_canceled_test.res`

```rescript
open RescriptMocha

describe("Agent__Task Canceled State", () => {
  it("should transition from Submitted to Canceled", () => {
    let task = Agent__Task.make()
    let result = task->Agent__Task.transition(Cancel(None))

    Assert.deepEqual(result, Ok())
    Assert.ok(task->Agent__Task.isTerminal)

    switch task->Agent__Task.getState {
    | Canceled(_) => Assert.ok(true)
    | _ => Assert.fail("Expected Canceled state")
    }
  })

  it("should transition from Working to Canceled", () => {
    let task = Agent__Task.make()
    let _ = task->Agent__Task.transition(StartProcessing(None))
    let result = task->Agent__Task.transition(Cancel(None))

    Assert.deepEqual(result, Ok())
  })

  it("should transition from InputRequired to Canceled", () => {
    let task = Agent__Task.make()
    let inputMsg = Agent__Message.make(
      ~role=Agent,
      ~parts=[Agent__Part.text(~text="Need input")],
    )
    let _ = task->Agent__Task.transition(StartProcessing(None))
    let _ = task->Agent__Task.transition(RequestInput(inputMsg))
    let result = task->Agent__Task.transition(Cancel(None))

    Assert.deepEqual(result, Ok())
  })

  it("should not allow transitions from Canceled", () => {
    let task = Agent__Task.make()
    let _ = task->Agent__Task.transition(Cancel(None))
    let result = task->Agent__Task.transition(StartProcessing(None))

    switch result {
    | Error(msg) => Assert.ok(msg->String.includes("Cannot transition"))
    | Ok() => Assert.fail("Should not allow transition from Canceled")
    }
  })

  it("should preserve cancel message", () => {
    let task = Agent__Task.make()
    let cancelMsg = Agent__Message.make(
      ~role=Agent,
      ~parts=[Agent__Part.text(~text="User canceled")],
    )
    let _ = task->Agent__Task.transition(Cancel(Some(cancelMsg)))

    let status = task->Agent__Task.getStatus
    Assert.ok(status.message->Option.isSome)
  })
})
```

#### 2. TaskStatus Tests
**File**: Create `libs/agent/test/Agent__Task_status_test.res`

```rescript
open RescriptMocha

describe("Agent__Task TaskStatus", () => {
  it("should have TaskStatus with state, message, timestamp", () => {
    let task = Agent__Task.make()
    let status = task->Agent__Task.getStatus

    // Should have all three fields
    Assert.ok(status.state !== undefined)
    Assert.ok(status.message !== undefined)
    Assert.ok(status.timestamp !== undefined)
  })

  it("should update timestamp on transition", () => {
    let task = Agent__Task.make()
    let status1 = task->Agent__Task.getStatus
    let timestamp1 = status1.timestamp

    // Transition
    let _ = task->Agent__Task.transition(StartProcessing(None))
    let status2 = task->Agent__Task.getStatus
    let timestamp2 = status2.timestamp

    // Timestamp should be different (later)
    Assert.notEqual(
      timestamp1->Agent__Task.Timestamp.toString,
      timestamp2->Agent__Task.Timestamp.toString
    )
  })

  it("should preserve message in status", () => {
    let task = Agent__Task.make()
    let inputMsg = Agent__Message.make(
      ~role=Agent,
      ~parts=[Agent__Part.text(~text="Need info")],
    )

    let _ = task->Agent__Task.transition(StartProcessing(None))
    let _ = task->Agent__Task.transition(RequestInput(inputMsg))

    let status = task->Agent__Task.getStatus
    Assert.ok(status.message->Option.isSome)
  })

  it("should have no message for Submitted state", () => {
    let task = Agent__Task.make()
    let status = task->Agent__Task.getStatus

    Assert.equal(status.message, None)
  })
})
```

#### 3. Integration Test Update
**File**: Update existing tests that access `task.state`

Search for `task.state` and update to `task.status.contents.state` or use `getState`:

```bash
# Find files that need updating
grep -r "task\.state" libs/agent/test/
```

Update pattern:
```rescript
// OLD:
switch task.state.contents {
| Completed(_) => // ...
}

// NEW:
switch task->Agent__Task.getState {
| Completed(_) => // ...
}
```

### Success Criteria:

#### Automated Verification:
- [ ] All new tests pass: `make -C libs/agent test`
- [ ] All existing tests still pass (after updates)
- [ ] No compiler warnings

#### Manual Verification:
- [ ] Test output clearly shows Canceled state working
- [ ] TaskStatus structure validated in tests
- [ ] Timestamp updates visible in test output

---

## Phase 4: Documentation

### Overview
Update documentation to reflect TaskStatus structure and Canceled state.

### Changes Required:

#### 1. Update Research Document
**File**: `research_task_lifecycle.md`
**Changes**: Add implementation results at end

```markdown
## Implementation Results (2025-10-15)

### Changes Implemented

**Phase 1: Canceled State**
- Added `Canceled` state variant to `State.t` union
- Added `Cancel` event to `State.event`
- Transitions from Submitted, Working, InputRequired → Canceled
- Canceled is terminal state (no outgoing transitions)
- Optional message field for cancellation reason

**Phase 2: TaskStatus Wrapper**
- Wrapped State in TaskStatus object: `{state, message, timestamp}`
- Task entity now has `status: ref<TaskStatus.t>` instead of `state: ref<State.t>`
- TaskStatus.timestamp updated on every transition
- Per-state timestamps preserved internally (extra detail)
- Structure now matches A2A TaskStatus specification

**Alignment Achieved:**
- ✅ All 7 A2A states supported (7/7)
- ✅ TaskStatus structure matches A2A spec
- ✅ Single timestamp at TaskStatus level (A2A compatible)
- ✅ Per-state timestamps preserved (internal audit trail)
- ✅ History mandatory (simplified implementation)
- ✅ Full type safety maintained

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
```

#### 2. Add Code Example
**File**: Create `libs/agent/examples/task_lifecycle.md`

```markdown
# Task Lifecycle Examples

## Creating and Using Tasks

```rescript
// Create a task
let task = Agent__Task.make(~contextId=Some(contextId))

// Check initial status
let status = task->Agent__Task.getStatus
// status = { state: Submitted, message: None, timestamp: <now> }

// Add a message
let userMsg = Agent__Message.make(~role=User, ~parts=[...])
task->Agent__Task.addMessage(userMsg)

// Start processing
let _ = task->Agent__Task.transition(StartProcessing(None))

// Check status again
let status = task->Agent__Task.getStatus
// status = { state: Working, message: None, timestamp: <updated> }
```

## Canceling a Task

```rescript
// User cancels during processing
let cancelMsg = Agent__Message.make(
  ~role=Agent,
  ~parts=[Agent__Part.text(~text="Canceled by user request")],
)
let result = task->Agent__Task.transition(Cancel(Some(cancelMsg)))

// Verify it's terminal
Assert.ok(task->Agent__Task.isTerminal)

// Check final status
let status = task->Agent__Task.getStatus
// status = { state: Canceled, message: Some(...), timestamp: <final> }
```

## TaskStatus Structure

The `TaskStatus.t` type contains:
- `state: State.t` - Current state (Submitted, Working, etc.)
- `message: option<Agent__Message.t>` - Optional associated message
- `timestamp: Timestamp.t` - Timestamp of current status

This matches the A2A Protocol TaskStatus object.
```

### Success Criteria:

#### Automated Verification:
- [ ] Documentation files are valid Markdown
- [ ] Code examples compile when extracted

#### Manual Verification:
- [ ] Research document accurately describes implementation
- [ ] Examples are clear and correct
- [ ] A2A alignment is well documented

---

## Testing Strategy

### Unit Tests:
- Canceled state transitions (all paths)
- TaskStatus structure validation
- Timestamp updates on transitions
- Message preservation in TaskStatus
- Terminal state enforcement

### Integration Tests:
- Canceled state in MessageHandler workflow
- Event emission for transitions
- Full lifecycle with TaskStatus
- Compatibility with existing code

### Manual Testing:
1. Create task, verify status.state is Submitted
2. Transition to Working, verify status.timestamp updated
3. Cancel task, verify status.state is Canceled
4. Verify cannot transition from Canceled
5. Check status structure matches A2A TaskStatus

## Performance Considerations

**Impact:**
- Minimal - wrapping state in TaskStatus adds one level of indirection
- Per-state timestamps unchanged (already existed)
- TaskStatus.timestamp updated on transitions (same as before)
- No additional memory allocations

**Memory:**
- TaskStatus adds ~24 bytes per task (state ref + message option + timestamp)
- Negligible in practice

## Migration Notes

**Breaking Changes:**
- `task.state` → `task.status` (field renamed)
- Code accessing `task.state.contents` needs update
- Use `task->Agent__Task.getState` instead for compatibility

**Update Pattern:**
```rescript
// OLD:
let currentState = task.state.contents
switch task.state.contents {
| Completed(_) => // ...
}

// NEW:
let currentState = task->Agent__Task.getState
// or
let status = task->Agent__Task.getStatus
switch status.state {
| Completed(_) => // ...
}
```

**Compatibility:**
- `getState()` API unchanged - returns State.t
- `transition()` API unchanged - takes event
- `isTerminal()` API unchanged
- New `getStatus()` returns full TaskStatus.t

**Adoption Steps:**
1. Run build: `make -C libs/agent build`
2. Fix compiler errors (exhaustive pattern matching for Canceled)
3. Update any code accessing `task.state` directly
4. Run tests: `make -C libs/agent test`
5. Update tests accessing `task.state.contents`

## References

- Research document: `research_task_lifecycle.md`
- A2A Spec Task: `docs/specification.md` Section 6.1
- A2A Spec TaskStatus: `docs/specification.md` Section 6.2
- A2A Spec TaskState: `docs/specification.md` Section 6.3
- Implementation: `libs/agent/src/Agent__Task.res`
