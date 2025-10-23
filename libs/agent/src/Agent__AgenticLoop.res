// Agentic loop - handles the continuous LLM interaction cycle with tool execution
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

// Main agentic loop: keep calling LLM while it needs tool calls
module Adapter = Agent__Adapters__Vercel
let run = async (
  llm: Adapter.t,
  executeCommand: (Agent__Task__Id.t, Agent__Task__Commands.t) => result<Agent__Task.t, string>,
  task: Agent__Task.t,
) => {
  Console.log("=== Starting agentic loop")

  // Transition task to Working status to prevent re-triggering
  let workingTask = switch executeCommand(
    task.id,
    Agent__Task__Commands.StartProcessing({message: None}),
  ) {
  | Ok(t) => t
  | Error(e) => {
      Console.error(`Failed to start processing: ${e}`)
      task
    }
  }

  // Start the agent loop
  let rec loop = async (currentTask: Agent__Task.t) => {
    let history = currentTask->Agent__Task.getHistory
    Console.log(`=== Loop iteration starting with ${history->Array.length->Int.toString} messages`)
    let result = await Adapter.streamText(llm, history)
    let stream = result->Adapter.getFullStream
    await Adapter.processAsyncIterable(stream, async event => {
      switch event {
      | TextDelta({textDelta}) => Console.log(textDelta)
      | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
      | _ => ()
      }
    })

    // Add LLM generated messages to task history (CRITICAL!)
    let response = await result->Adapter.getResponse
    Console.log2("Response messages count:", response.messages->Array.length)

    // Convert ALL messages (assistant + tool) to domain format and add to task
    let taskWithNewMessages = response.messages->Array.reduce(currentTask, (task, vercelMsg) => {
      let domainMessage = Adapter.messageFromVercel(vercelMsg)->Option.getOrThrow
      switch executeCommand(task.id, Agent__Task__Commands.AddMessage({message: domainMessage})) {
      | Ok(updatedTask) => updatedTask
      | Error(e) => {
          Console.error(`Failed to add message: ${e}`)
          task
        }
      }
    })

    // Check finish reason to decide whether to continue
    let finishReason = await result->Adapter.getFinishReason
    Console.log2("=== Finish reason:", finishReason)
    Console.log2(
      "Current message history length:",
      taskWithNewMessages->Agent__Task.getHistory->Array.length,
    )

    if finishReason == ToolCalls {
      // Debug: Let's see what messages Vercel returns
      Console.log("=== DEBUG: All response.messages after tool-calls finish reason")
      response.messages->Array.forEachWithIndex((msg, idx) => {
        Console.log2(`Message ${idx->Int.toString}:`, msg)
      })

      // Continue the loop with current task (tool results should already be in response.messages)
      Console.log("=== Continuing loop")
      await loop(taskWithNewMessages)
    } else {
      // No more tool calls - task is complete
      Console.log2("=== No tool calls, completing task. Finish reason was:", finishReason)

      // All messages have already been added above
      // Get the last message (should be the final assistant message)
      let history = taskWithNewMessages->Agent__Task.getHistory
      let lastMessage = history->Array.at(-1)

      // Transition task to complete
      let _ = executeCommand(
        taskWithNewMessages.id,
        Agent__Task__Commands.Complete({message: lastMessage}),
      )

      Console.log("=== Agentic loop completed successfully")
    }
  }

  // Start the loop with initial task
  Console.log("=== Calling loop for the first time")
  await loop(workingTask)
  Console.log("=== Agentic loop finished")
}
