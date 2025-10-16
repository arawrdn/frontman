# Agentic Loop Implementation Plan

## Overview

Implement an agentic execution loop in `libs/agent/` that enables the agent to autonomously execute tool calls in a loop until the LLM completes its response. The loop will process streaming LLM responses, detect tool calls, execute tools manually, and continue the conversation until no more tool calls are requested.

## Current State Analysis

### What Exists:

**EventBus** (`Agent__EventBus.res:1-43`):
- Simple pub/sub system with 3 event types:
  - `TaskStateChanged` - task status transitions
  - `ArtifactChunkGenerated` - streaming artifacts
  - `TaskMessageAdded` - message added to history

**MessageHandler** (`Agent__MessageHandler.res:9-108`):
- Entry point via `Agent.sendMessage`
- Current flow is **fire-and-forget**:
  1. Creates/retrieves task
  2. Adds user message to history
  3. Transitions task to Working
  4. Calls `llm.chat()` once
  5. Gets simple string response (no tool handling)
  6. Marks task Complete
  7. Emits events

**LLM Interface** (`Agent__LLM.res:12-55`):
- `chat()` function converts messages to Vercel AI format
- Calls `streamText` but only returns final text
- **Does not handle tool calls or streaming**

**StreamProcessor** (`Agent__StreamProcessor.res:21-96`):
- Has logic to process `fullStream` events
- Handles `TextDelta`, `ToolCall`, `ToolResult`, `FinishStep`, `Finish`
- Tracks tool execution state
- **Currently unused in the codebase**

**Tools Registry** (`Agent__Tools__Registry.res:25-108`):
- Tools defined with `execute` functions:
  - `read_file` - reads file contents
  - `write_file` - writes file contents
  - `list_files` - lists directory contents
- Execute functions wrapped to handle errors

**Vercel Adapter** (`Agent__Adapters__Vercel.res:1-76`):
- Converts domain types to Vercel AI format
- `toVercelTools` - converts tools registry to Vercel format
- `messageToVercel` - converts Agent__Message.t to Vercel message format
- `messagesToVercel` - batch conversion helper

### Key Discoveries:
- Vercel AI SDK `streamText` has `maxSteps` parameter for auto-looping, but we want manual control
- `fullStream` returns async iterable with typed events
- Tools are already registered with executable implementations
- StreamProcessor has infrastructure but needs integration

## Desired End State

An agent that can:
1. Receive user message via `Agent.sendMessage`
2. Enter agentic execution loop that:
   - Calls LLM with current history
   - Processes stream events in real-time
   - Detects tool calls from LLM
   - Executes tools with provided arguments
   - Adds tool results back to history as Agent messages
   - Loops back to call LLM again with updated history
   - Exits when LLM produces final text without tool calls
3. Emits completion events via EventBus

### Verification:
- Agent can successfully execute multi-turn tool calling sequences
- Tool results are properly added to conversation history
- Final response is delivered after all tool calls complete
- Events are emitted at appropriate lifecycle points
- Tests demonstrate multi-step agentic behavior

## What We're NOT Doing

- Using Vercel AI's `maxSteps` auto-loop (we want manual control)
- Creating new event types (using existing `TaskStateChanged` + `TaskMessageAdded`)
- Modifying EventBus structure or API
- Adding UI/client integration (that's handled separately)
- Implementing new tools (using existing filesystem tools)
- Handling artifacts or streaming responses to client (future work)

## Implementation Approach

We'll refactor the LLM execution to use streaming with manual tool call handling. The core change is in `Agent__MessageHandler.processMessage` - replacing the simple `llm.chat()` call with a loop that:

1. Calls `Agent__LLM.streamText` to get stream
2. Uses `Agent__StreamProcessor` to process events
3. Detects tool calls and executes them
4. Adds tool results as Agent messages to history
5. Repeats until LLM produces final response

This keeps the same entry point (`Agent.sendMessage`) and event emissions, just changes the execution model.

---

## Phase 1: Refactor LLM Interface for Streaming

### Overview
Modify `Agent__LLM` to expose streaming interface that returns the stream directly rather than just the final text. This gives us access to tool call events.

### Changes Required:

#### 1. `Agent__LLM.res`
**File**: `libs/agent/src/Agent__LLM.res`
**Changes**: Add new `streamText` function that returns the stream result, keep existing `chat` for backward compatibility

```rescript
// New function: returns stream for manual processing
let streamText = async (llm: t, messages: array<Agent__Message.t>): Agent__Bindings__VercelAI.streamTextResult => {
  // Convert Agent__Message.t to Vercel AI format using adapter
  let vercelMessages = Agent__Adapters__Vercel.messagesToVercel(messages)

  // Call LLM - explicitly set maxSteps to None to disable auto-looping
  await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: Some(llm.tools),
    maxSteps: None,  // Manual control
  })
}

// Keep existing chat function for backward compatibility
let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  let result = await streamText(llm, messages)
  await result->Agent__Bindings__VercelAI.text
}
```

### Success Criteria:

#### Automated Verification:
- [x] ReScript compilation passes: `make -C libs/agent build`
- [x] Type checking passes (no type errors)
- [x] Existing code using `chat` still works

#### Manual Verification:
- [x] `streamText` returns stream result that can be processed
- [x] `chat` still returns final text string

---

## Phase 2: Enhance StreamProcessor for Tool Result Extraction

### Overview
Modify `Agent__StreamProcessor` to return structured data including tool calls and final text in a format suitable for driving the agentic loop.

### Changes Required:

#### 1. `Agent__StreamProcessor.res`
**File**: `libs/agent/src/Agent__StreamProcessor.res`
**Changes**: Return structured result with tool calls array and final text

```rescript
// Result type returned by processor
type processResult = {
  text: string,
  toolCalls: array<toolPart>,
  hasToolCalls: bool,
}

// Process stream and collect events
let process = async (_requestId: string, stream: Agent__Bindings__VercelAI.streamTextResult): processResult => {
  let toolParts = Dict.make()
  let textBuffer = ref("")

  let iterator =
    stream
    ->Agent__Bindings__VercelAI.fullStream
    ->Agent__Bindings__VercelAI.AsyncIterableStream.toAsyncIterator

  await processAsyncIterator(iterator, async event => {
    switch event {
    | TextDelta({textDelta}) => textBuffer := textBuffer.contents ++ textDelta

    | ToolCall({toolCallId, toolName, args}) => {
        Console.error2("Tool call:", toolName)

        let toolPart = {
          id: toolCallId,
          toolCallId,
          toolName,
          status: ref(Running),
          input: ref(Some(args)),
          output: ref(None),
          error: ref(None),
          startTime: ref(Some(Date.now())),
          endTime: ref(None),
        }

        toolParts->Dict.set(toolCallId, toolPart)
      }

    | ToolResult({toolCallId, toolName, result}) => {
        Console.error2("Tool result:", toolName)

        switch toolParts->Dict.get(toolCallId) {
        | Some(part) => {
            part.status := Completed
            part.output := Some(result->JSON.stringify)
            part.endTime := Some(Date.now())
          }
        | None => Console.error("Tool result without matching call")
        }
      }

    | FinishStep({finishReason, usage}) => Console.error3("Step finished:", finishReason, usage)

    | Finish => Console.error("Stream finished")
    }
  })

  let toolCallsArray = toolParts->Dict.valuesToArray

  {
    text: textBuffer.contents,
    toolCalls: toolCallsArray,
    hasToolCalls: toolCallsArray->Array.length > 0,
  }
}
```

### Success Criteria:

#### Automated Verification:
- [x] ReScript compilation passes: `make -C libs/agent build`
- [x] Type checking passes
- [ ] Unit test for `processResult` structure: `make -C libs/agent test`

#### Manual Verification:
- [x] `processResult` contains expected fields
- [x] `hasToolCalls` correctly indicates presence of tool calls

---

## Phase 3: Implement Tool Execution

### Overview
Create utility function to execute a tool call using the tools registry. This bridges the gap between detecting a tool call in the stream and actually executing it.

### Changes Required:

#### 1. `Agent__MessageHandler.res`
**File**: `libs/agent/src/Agent__MessageHandler.res`
**Changes**: Add helper function to execute tool calls

```rescript
// Execute a single tool call
let executeTool = async (
  agent: Agent__Types.Agent.t,
  toolName: string,
  args: JSON.t,
): result<string, string> => {
  // Look up tool in registry
  switch agent.tools->Dict.get(toolName) {
  | Some(toolDef) => {
      switch toolDef.execute {
      | Some(execFn) => {
          try {
            let result = await execFn(args)
            Ok(result->JSON.stringify)
          } catch {
          | exn => {
              let message =
                exn
                ->JsExn.fromException
                ->Option.flatMap(JsExn.message)
                ->Option.getOr("Unknown error")
              Error(`Tool execution failed: ${message}`)
            }
          }
        }
      | None => Error(`Tool ${toolName} has no execute function`)
      }
    }
  | None => Error(`Tool ${toolName} not found in registry`)
  }
}
```

### Success Criteria:

#### Automated Verification:
- [x] ReScript compilation passes: `make -C libs/agent build`
- [ ] Unit test for `executeTool`: `make -C libs/agent test`

#### Manual Verification:
- [x] Tool execution returns expected results
- [x] Error handling works for missing tools
- [x] Error handling works for execution failures

---

## Phase 4: Implement Agentic Loop

### Overview
Replace the simple `llm.chat()` call in `processMessage` with an agentic loop that handles tool calling iteratively.

### Changes Required:

#### 1. `Agent__MessageHandler.res`
**File**: `libs/agent/src/Agent__MessageHandler.res`
**Changes**: Replace `processStream` implementation with agentic loop

```rescript
let processMessage = (agent: Agent__Types.Agent.t, config: processMessageConfig) => {
  let {taskId, contextId, userMessage} = config

  // Get or create task
  let task = switch taskId {
  | Some(id) =>
    switch agent.tasks.contents->Dict.get(Agent__Id.toString(id)) {
    | Some(existingTask) => existingTask
    | None =>
      Console.error("Task not found, creating new task")
      let newTask = Agent__Task.makeWithId(~id, ~contextId)
      agent.tasks.contents->Dict.set(Agent__Id.toString(id), newTask)
      newTask
    }
  | None =>
    let newTask = Agent__Task.make(~contextId)
    agent.tasks.contents->Dict.set(Agent__Id.toString(newTask.id), newTask)
    newTask
  }

  // Add user message to history
  task->Agent__Task.addMessage(userMessage)

  // Transition task status
  let _ = switch task->Agent__Task.getStatus {
  | Submitted(_) => task->Agent__Task.transition(StartProcessing(None))
  | InputRequired(_) => task->Agent__Task.transition(Resume(None))
  | _ => Ok()
  }

  // Emit TaskStateChanged event
  agent.eventBus->Agent__EventBus.emit(
    TaskStateChanged({
      taskId: task.id,
      contextId: task.contextId,
    }),
  )

  // Agentic loop: keep calling LLM while it needs tool calls
  let rec agenticLoop = async () => {
    try {
      // Get current history
      let history = task->Agent__Task.getHistory

      // Call LLM with streaming
      let stream = await agent.llm->Agent__LLM.streamText(history)

      // Process stream to get tool calls and text
      let result = await Agent__StreamProcessor.process("", stream)

      // Check if LLM requested tool calls
      if result.hasToolCalls {
        Console.error("Processing tool calls...")

        // Execute each tool call
        let toolResults = await result.toolCalls
        ->Array.map(async toolCall => {
          let toolName = toolCall.toolName
          let args = toolCall.input.contents->Option.getOr(JSON.Encode.null)

          Console.error2(`Executing tool: ${toolName}`, args)

          let result = await executeTool(agent, toolName, args)

          switch result {
          | Ok(output) => {
              Console.error2(`Tool ${toolName} succeeded:`, output)
              (toolName, output, None)
            }
          | Error(err) => {
              Console.error2(`Tool ${toolName} failed:`, err)
              (toolName, "", Some(err))
            }
          }
        })
        ->Promise.all

        // Add tool results to history as Agent messages
        toolResults->Array.forEach(((toolName, output, error)) => {
          let resultText = switch error {
          | Some(err) => `Tool ${toolName} error: ${err}`
          | None => `Tool ${toolName} result: ${output}`
          }

          let toolResultMessage = Agent__Message.make(
            ~role=Agent,
            ~parts=[Agent__Part.text(~text=resultText)],
            ~taskId=Some(task.id),
            ~contextId=task.contextId,
          )

          task->Agent__Task.addMessage(toolResultMessage)

          // Emit TaskMessageAdded event
          agent.eventBus->Agent__EventBus.emit(
            TaskMessageAdded({
              taskId: task.id,
              message: toolResultMessage,
            }),
          )
        })

        // Loop back: call LLM again with tool results
        await agenticLoop()
      } else {
        // No tool calls - we're done
        Console.error("No tool calls, completing task")

        // Create final agent message with text response
        let agentMessage = Agent__Message.make(
          ~role=Agent,
          ~parts=[Agent__Part.text(~text=result.text)],
          ~taskId=Some(task.id),
          ~contextId=task.contextId,
        )

        // Add to history
        task->Agent__Task.addMessage(agentMessage)

        // Emit TaskMessageAdded event
        agent.eventBus->Agent__EventBus.emit(
          TaskMessageAdded({
            taskId: task.id,
            message: agentMessage,
          }),
        )

        // Complete task
        let _ = task->Agent__Task.transition(Complete(Some(agentMessage)))

        // Emit TaskStateChanged event
        agent.eventBus->Agent__EventBus.emit(
          TaskStateChanged({
            taskId: task.id,
            contextId: task.contextId,
          }),
        )
      }
    } catch {
    | error =>
      Console.error2("Error in agentic loop:", error)
      let errorMessage = Agent__Message.make(
        ~role=Agent,
        ~parts=[Agent__Part.text(~text="Error processing request")],
        ~taskId=Some(task.id),
        ~contextId=task.contextId,
      )

      let _ = task->Agent__Task.transition(Fail(errorMessage))

      agent.eventBus->Agent__EventBus.emit(
        TaskStateChanged({
          taskId: task.id,
          contextId: task.contextId,
        }),
      )
    }
  }

  // Start the agentic loop
  agenticLoop()->ignore
}
```

### Success Criteria:

#### Automated Verification:
- [x] ReScript compilation passes: `make -C libs/agent build`
- [ ] Unit test with mock LLM that requests tool calls: `make -C libs/agent test`
- [ ] Test verifies loop continues until no tool calls

#### Manual Verification:
- [x] Agent successfully executes multi-turn conversations
- [x] Tool results are added to history
- [x] Loop terminates when LLM produces final text
- [x] Events are emitted at correct points

---

## Phase 5: Integration Testing

### Overview
Create comprehensive tests that verify the entire agentic loop with real tool execution.

### Changes Required:

#### 1. Create integration test
**File**: `libs/agent/test/agentic-loop.test.res.mjs`
**Changes**: New test file

```javascript
import { describe, it, expect } from 'vitest'
import { Agent } from '../src/Agent.res.mjs'
import { Message } from '../src/Agent__Message.res.mjs'
import { Part } from '../src/Agent__Part.res.mjs'

describe('Agentic Loop', () => {
  it('executes multi-turn tool calling sequence', async () => {
    const agent = Agent.make(process.cwd())
    const events = []

    // Subscribe to events
    const unsubscribe = agent.eventBus.on((event) => {
      events.push(event)
    })

    // Send message that requires tool calls
    const message = Message.make({
      role: 'User',
      parts: [Part.text({ text: 'Read the package.json file' })],
      taskId: null,
      contextId: null,
      metadata: null
    })

    const result = await Agent.sendMessage(agent, message)

    // Wait for completion
    await new Promise(resolve => setTimeout(resolve, 5000))

    // Verify events were emitted
    expect(events.length).toBeGreaterThan(0)

    // Verify task completed
    const [taskId, task] = result
    const status = task.getStatus()
    expect(status.TAG).toBe('Completed')

    // Verify history contains tool results
    const history = task.getHistory()
    expect(history.length).toBeGreaterThan(1)

    unsubscribe()
  }, 10000)
})
```

### Success Criteria:

#### Automated Verification:
- [ ] Integration test passes: `make -C libs/agent test`
- [ ] Test demonstrates multi-turn tool execution
- [ ] Test verifies events are emitted
- [ ] Test confirms task completion

#### Manual Verification:
- [ ] Run test with console output to see tool calls
- [ ] Verify tool execution logs show proper flow
- [ ] Check that conversation history is properly maintained

---

## Testing Strategy

### Unit Tests:
- Test `executeTool` with mock tools
- Test `StreamProcessor.process` returns correct structure
- Test error handling in tool execution

### Integration Tests:
- Test complete agentic loop with filesystem tools
- Test multi-turn conversations (LLM requests multiple tools)
- Test loop termination (LLM completes without tools)
- Test error recovery (tool fails, agent continues)

### Manual Testing Steps:
1. Start agent in test project
2. Send message: "Read package.json and tell me the project name"
3. Observe console logs showing:
   - Tool call detected
   - Tool execution
   - Tool result added to history
   - Final LLM response
4. Verify task completes successfully
5. Check event emissions via EventBus subscriber

## Performance Considerations

- Streaming processing is efficient for large responses
- Tool execution is async and non-blocking
- Loop has no maximum iteration count (relies on LLM to stop)
  - Consider adding safety limit (e.g., max 10 iterations) in future
- Event emission is synchronous but handlers are user-controlled

## Migration Notes

- No breaking changes to public API
- `Agent.sendMessage` signature unchanged
- Existing event types unchanged
- Backward compatible: old `chat` function still works

## References

- Vercel AI SDK: https://sdk.vercel.ai/docs
- Current implementation: `libs/agent/src/Agent__MessageHandler.res:9-108`
- Tool registry: `libs/agent/src/Agent__Tools__Registry.res:25-108`
- Stream processor: `libs/agent/src/Agent__StreamProcessor.res:21-96`
- Vercel adapter: `libs/agent/src/Agent__Adapters__Vercel.res:1-76`
