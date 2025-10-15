# A2A Alignment Specification for Ask-the-LLM Agent

**Version:** 1.0
**Date:** 2025-10-15
**Status:** Draft

## 1. Overview

This specification defines how the Ask-the-LLM agent will align with the Agent2Agent (A2A) Protocol terminology and concepts, preparing for future extraction as a standalone A2A-compliant agent while maintaining the current in-process architecture.

**Scope:** This alignment focuses on the middleware-to-agent API layer. Internally, the agent can use any abstractions needed, but the interface between framework middleware and agent library will use A2A concepts.

## 2. Core Terminology Alignment

### 2.1 Task-Based Model

**Decision:** Adopt A2A's Task concept from day one.

- Every interaction creates or continues a **Task** - a stateful entity with a unique ID
- Tasks progress through defined lifecycle states (submitted → working → input-required → completed/failed/canceled)
- Replace current "request/response" terminology with Task-based thinking

**Rationale:** Makes future A2A extraction trivial and provides better observability of operations.

### 2.2 Message Structure

**Decision:** Use A2A's Message model for all communication.

- Messages contain a `role` (user or agent)
- Messages contain `parts` array (TextPart, FilePart, DataPart)
- User content goes in Message.parts
- Framework context goes in Message.metadata

## 3. State Management

### 3.1 Task Lifecycle Control

**Decision:** UI decides when to create new Task vs continue existing Task.

- UI is responsible for determining conversation boundaries
- UI includes `taskId` in message to continue existing Task
- UI omits `taskId` to create new Task
- Neither middleware nor agent make this decision

**Implementation:** Client-side state management in UI component.

### 3.2 Task State Transitions

**Decision:** Emit all state transitions.

Agent must emit TaskStatus updates for every state change:
- `submitted` - Task received, queued for processing
- `working` - Actively processing
- `input-required` - Agent needs user input to continue
- `completed` - Successfully finished
- `failed` - Error occurred
- `rejected` - Agent refused the request

**Not implemented initially:**
- `auth-required` - Deferred for future
- `canceled` - No cancellation support initially

**Rationale:** Full observability provides complete audit trail and helps debugging.

### 3.3 Task History Ownership

**Decision:** Agent owns and maintains Task history.

- Agent stores all Messages (user and agent) in Task.history array
- Agent is authoritative source for Task state
- Middleware does not duplicate or manage conversation history

**Rationale:** Agent is already stateful; centralizing Task state in agent keeps clear ownership.

## 4. Context Handling

### 4.1 Framework Context Delivery

**Decision:** Use Message.metadata for framework context.

Framework-specific context (compilation errors, logs, routes) is passed in `Message.metadata`:

```typescript
{
  message: {
    role: "user",
    parts: [{ kind: "text", text: "Fix the TypeScript error" }],
    messageId: "msg-001",
    metadata: {
      compilationErrors: [...],
      recentLogs: [...],
      currentRoute: "...",
      frameworkInfo: {...}
    }
  }
}
```

**Rationale:**
- Keeps Message.parts clean for actual user content
- Leverages A2A's extension mechanism
- Framework context is supplementary to user message

### 4.2 Context Scope

Framework context includes:
- Compilation errors and warnings
- Recent runtime logs (configurable buffer)
- Current route/page information
- Build status and metrics
- Any other framework-specific state

Context is bundled by middleware at call time, not requested on-demand by agent.

## 5. API Surface Design

### 5.1 Function Signature

**Decision:** Align with A2A's `message/send` structure.

```typescript
function sendMessage(params: MessageSendParams): Promise<Task>
```

Where `MessageSendParams` matches A2A specification:
```typescript
interface MessageSendParams {
  message: Message;
  configuration?: MessageSendConfiguration;
  metadata?: Record<string, any>;
}
```

**Rationale:** Direct alignment with A2A spec makes future extraction seamless.

### 5.2 Return Type

**Decision:** Always return Task object.

- Even for simple/immediate responses, return a completed Task
- No "quick response Message" path
- Consistent type handling in middleware

**Rationale:** Given that agent does LLM calls and file operations, most interactions aren't instant. Consistent Task return type simplifies middleware logic.

### 5.3 Callback Mechanism

**Decision:** Callback returns void, agent mutates Task.

```typescript
interface AgentCallbacks {
  onStatusUpdate: (task: Task) => void;
}

function sendMessage(
  params: MessageSendParams,
  callbacks: AgentCallbacks
): Promise<Task>
```

- Agent calls `onStatusUpdate(task)` with updated Task object
- Callback is notification-only, doesn't return data
- Agent is responsible for Task state mutation

**Rationale:** Clear ownership model - agent controls Task state, middleware observes.

## 6. Multi-Turn Interactions

### 6.1 Input-Required Pattern

**Decision:** Agent pauses and returns Task in `input-required` state.

Flow for agent requesting user input:
1. Agent determines it needs user clarification
2. Agent updates Task.status.state to `input-required`
3. Agent sets Task.status.message to agent Message with question
4. Agent calls `onStatusUpdate(task)` with updated Task
5. Agent function returns the Task (in input-required state)
6. Middleware forwards Task to UI
7. UI displays agent's question to user
8. User responds, UI sends new `message/send` call with same `taskId`
9. Agent resumes processing from where it paused

**Implementation Requirements:**
- Agent must be able to serialize/restore internal state to resume Tasks
- Task object must contain enough context to resume
- Middleware does not block or synchronously wait for user input

**Rationale:** Maintains clean boundaries, fully A2A-compliant, allows async user interaction.

### 6.2 Task Resumption

When continuing a Task (message includes existing `taskId`):
- Agent loads Task from internal state
- Agent appends new user Message to Task.history
- Agent continues processing from previous state
- Agent maintains continuity of conversation context

## 7. Output Structure

### 7.1 Artifacts

**Decision:** Simple text Artifacts initially.

- Agent creates Artifact objects with TextPart content
- All output (explanations, file change summaries) as text
- Example: "I modified Button.tsx and updated the styles to fix the TypeScript error"

**Future Extension:** May add FilePart (with file paths/URIs) and DataPart (structured JSON) later.

**Rationale:** Start simple, add structure when needed. UI can parse text summaries initially.

### 7.2 TaskStatus Messages

**Decision:** Include agent Messages in TaskStatus updates.

- Status transitions include explanatory messages
- Examples:
  - `working` + "Analyzing your TypeScript errors..."
  - `input-required` + "Which approach would you prefer: A or B?"
  - `completed` + "I've successfully fixed the compilation error"

**Rationale:** Better UX, users see what agent is doing at each step.

## 8. Features Deferred for Initial Implementation

### 8.1 Not Implemented Initially

- **Task Cancellation** (`tasks/cancel`) - Tasks run to completion or failure
- **Context IDs** (`contextId`) - No logical grouping of Tasks
- **Auth-Required State** - Not needed for embedded development tool
- **Streaming** (`message/stream`) - Use callbacks instead of SSE
- **Push Notifications** - Not applicable to in-process architecture
- **Rich Artifacts** - Text only initially, no FilePart/DataPart

### 8.2 Out of Scope

These A2A features don't apply to current architecture:
- Agent Card - No discovery needed (agent is embedded)
- HTTP/REST transport - Using direct function calls
- JSON-RPC protocol - Using native JavaScript calls
- Authentication - Runs in developer's process
- gRPC transport - Not needed for in-process

## 9. Implementation Phases

### Phase 1: Core Task Model (Immediate)

- [ ] Define TypeScript interfaces matching A2A Task, Message, Part structures
- [ ] Implement Task state management in agent
- [ ] Update agent function signature to `sendMessage(params, callbacks)`
- [ ] Implement state transition emissions via `onStatusUpdate`
- [ ] Update middleware to construct MessageSendParams with framework context in metadata

### Phase 2: Multi-Turn Support

- [ ] Implement `input-required` state handling
- [ ] Add Task serialization/restoration for resumption
- [ ] Update UI to handle Task continuation (include taskId in subsequent calls)
- [ ] Test multi-turn conversation flows

### Phase 3: History and Artifacts

- [ ] Implement Task.history management in agent
- [ ] Structure agent output as Artifact objects with TextParts
- [ ] Add TaskStatus.message to all state transitions

### Phase 4: Future Enhancements (Post-Extraction)

- Implement Task cancellation
- Add rich Artifacts (FilePart, DataPart)
- Introduce Context IDs for conversation grouping
- Extract to standalone agent with HTTP/REST transport
- Implement full A2A protocol (Agent Card, streaming, push notifications)

## 10. Data Structure Examples

### 10.1 Creating a New Task

**UI → Middleware → Agent:**
```typescript
sendMessage({
  message: {
    role: "user",
    parts: [
      { kind: "text", text: "Fix the TypeScript error in Button.tsx" }
    ],
    messageId: "msg-001",
    metadata: {
      compilationErrors: [
        {
          file: "Button.tsx",
          line: 15,
          message: "Property 'onClick' does not exist on type 'ButtonProps'"
        }
      ],
      recentLogs: [],
      currentRoute: "/components"
    }
  }
}, {
  onStatusUpdate: (task) => { /* forward to UI */ }
})
```

**Agent → Middleware (via callback):**
```typescript
// State: submitted
{
  id: "task-abc123",
  status: {
    state: "submitted",
    timestamp: "2025-10-15T10:00:00Z"
  },
  history: [
    {
      role: "user",
      parts: [{ kind: "text", text: "Fix the TypeScript error in Button.tsx" }],
      messageId: "msg-001",
      taskId: "task-abc123"
    }
  ],
  artifacts: []
}

// State: working
{
  id: "task-abc123",
  status: {
    state: "working",
    message: {
      role: "agent",
      parts: [{ kind: "text", text: "Analyzing the TypeScript error in Button.tsx..." }],
      messageId: "msg-002",
      taskId: "task-abc123"
    },
    timestamp: "2025-10-15T10:00:01Z"
  },
  history: [...],
  artifacts: []
}

// State: completed
{
  id: "task-abc123",
  status: {
    state: "completed",
    message: {
      role: "agent",
      parts: [{ kind: "text", text: "I've fixed the TypeScript error by adding the onClick property to ButtonProps." }],
      messageId: "msg-003",
      taskId: "task-abc123"
    },
    timestamp: "2025-10-15T10:00:15Z"
  },
  history: [
    { role: "user", ... },
    { role: "agent", messageId: "msg-002", ... },
    { role: "agent", messageId: "msg-003", ... }
  ],
  artifacts: [
    {
      artifactId: "artifact-001",
      name: "Fix Result",
      parts: [
        {
          kind: "text",
          text: "Modified Button.tsx:\n- Added onClick?: () => void to ButtonProps interface\n- The component now compiles without errors"
        }
      ]
    }
  ]
}
```

### 10.2 Continuing a Task (Multi-Turn)

**UI → Middleware → Agent:**
```typescript
sendMessage({
  message: {
    role: "user",
    parts: [
      { kind: "text", text: "Option A please" }
    ],
    messageId: "msg-005",
    taskId: "task-abc123", // <-- Continuing existing Task
    metadata: {
      // Fresh framework context
      compilationErrors: [],
      recentLogs: [...]
    }
  }
}, callbacks)
```

## 11. Benefits of This Approach

### 11.1 Immediate Benefits

- **Clear Boundaries:** Separation between UI, middleware, and agent responsibilities
- **Observability:** Full Task state tracking provides insight into agent operations
- **Extensibility:** Message.metadata allows framework-specific context without breaking A2A model
- **Consistency:** Uniform Task model simplifies error handling and state management

### 11.2 Future Benefits

- **Easy Extraction:** When agent becomes standalone, core data structures already match A2A
- **Multi-Framework Support:** Other frameworks can integrate using same Task/Message API
- **Standard Compliance:** Aligned with open protocol enables interoperability
- **Minimal Refactoring:** Internal agent logic can remain unchanged during extraction

## 12. Migration Path to Standalone Agent

When extracting agent to standalone process:

1. **Transport Layer:** Replace function calls with HTTP/REST or JSON-RPC
2. **Agent Card:** Create Agent Card describing skills and endpoints
3. **Authentication:** Add security schemes for external access
4. **Add A2A Methods:** Implement `tasks/get`, optional streaming, push notifications
5. **Discovery:** Publish Agent Card at well-known URI

Core Task/Message structures remain unchanged - only transport mechanism changes.

## 13. Validation and Testing

### 13.1 Validation Criteria

Implementation is correct when:
- [ ] Agent API matches A2A MessageSendParams structure
- [ ] All Task objects include valid state transitions
- [ ] TaskStatus updates emit for every state change
- [ ] Multi-turn interactions maintain Task continuity
- [ ] Framework context properly embedded in Message.metadata
- [ ] Agent Messages included in TaskStatus for observability

### 13.2 Test Scenarios

1. **Simple Task:** User asks question, agent responds immediately with completed Task
2. **Multi-Turn:** Agent asks for clarification (input-required), user responds, Task continues
3. **Error Handling:** Task fails gracefully with failed state and error message
4. **State Transitions:** All states (submitted → working → completed) emit correctly
5. **History Management:** Task.history accurately reflects conversation

## 14. References

- **A2A Specification:** `/docs/specification.md` (v0.3.0)
- **Current Architecture:** `/docs/architecture.md` (v1.3)
- **A2A Protocol:** https://a2a-protocol.org/

---

**Document Status:** Ready for implementation
**Next Step:** Review with team, then proceed to Phase 1 implementation
