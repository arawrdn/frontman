// Agentic loop - handles the continuous LLM interaction cycle with tool execution
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

// Execute a single tool call
let executeTool = async (llm: Agent__Adapters__Vercel.t, toolName: string, args: JSON.t): result<
  string,
  string,
> => {
  await Agent__Adapters__Vercel.executeTool(llm, ~toolName, ~args)
}

// Main agentic loop: keep calling LLM while it needs tool calls
let run = async (
  llm: Agent__Adapters__Vercel.t,
  tasks: Agent__Tasks.t,
  eventBus: Agent__EventBus.t,
  task: Agent__Task.t,
) => {
  Console.log("=== Starting agentic loop")
  %debugger

  // Transition task to Working status to prevent re-triggering
  let workingTask = switch Agent__Task.transition(task, Agent__Task__Status.StartProcessing(None)) {
  | Ok(t) => {
      Agent__Tasks.update(tasks, t)
      Agent__EventBus.emit(eventBus, TaskStateChanged(t))
      t
    }
  | Error(_) => task
  }

  // Get current message history and convert to Vercel format
  let history = workingTask->Agent__Task.getHistory
  let userMessages = Agent__Adapters__Vercel.messagesToVercel(history)

  // Track message accumulation throughout loop iterations
  let messages = ref(userMessages)

  // Start the agent loop
  let rec loop = async (
    vercelMessages: array<Agent__Adapters__Vercel.vercelMessage>,
    currentTask: Agent__Task.t,
  ) => {
    Console.log(
      `=== Loop iteration starting with ${vercelMessages->Array.length->Int.toString} messages`,
    )

    // Call LLM with current message history
    let result = await Agent__Adapters__Vercel.streamTextWithVercelMessages(llm, vercelMessages)

    // Stream the response (for user updates - optional but recommended)
    let stream = result->Agent__Adapters__Vercel.getFullStream

    await Agent__Adapters__Vercel.processAsyncIterable(stream, async event => {
      switch event {
      | TextDelta({textDelta}) => Console.log(textDelta)
      | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
      | _ => ()
      }
    })

    // Add LLM generated messages to the message history (CRITICAL!)
    // NOTE: Only add assistant messages, not tool messages (we handle those ourselves)
    let response = await result->Agent__Adapters__Vercel.getResponse
    Console.log2("Response messages count:", response.messages->Array.length)
    let assistantMessages = response.messages->Array.filter(msg => msg.role == "assistant")
    Console.log2("Assistant messages count:", assistantMessages->Array.length)
    messages := Array.concat(messages.contents, assistantMessages)

    // Check finish reason to decide whether to continue
    let finishReason = await result->Agent__Adapters__Vercel.getFinishReason
    Console.log2("=== Finish reason:", finishReason)
    Console.log2("Current message history length:", messages.contents->Array.length)

    if finishReason == "tool-calls" {
      // Get tool calls and execute them
      let toolCalls = await result->Agent__Adapters__Vercel.getToolCalls

      Console.log("Processing tool calls...")

      // Execute all tool calls and collect results
      let toolResultMessages = await toolCalls
      ->Array.map(async toolCall => {
        let toolName = toolCall.toolName
        let args = toolCall.args
        Console.log2(`Executing tool: ${toolName}`, args)

        let toolResult = await executeTool(llm, toolName, args)

        switch toolResult {
        | Ok(output) => {
            Console.log2(`Tool ${toolName} succeeded:`, output)

            // Create tool result message in Vercel format
            Some(
              Agent__Adapters__Vercel.makeToolResultMessage(toolCall.toolCallId, toolName, output),
            )
          }
        | Error(err) => {
            Console.error2(`Tool ${toolName} failed:`, err)
            // Still need to return a result message for the LLM
            Some(
              Agent__Adapters__Vercel.makeToolResultMessage(
                toolCall.toolCallId,
                toolName,
                `Error: ${err}`,
              ),
            )
          }
        }
      })
      ->Promise.all

      // Add tool result messages to history
      let validToolResults = toolResultMessages->Array.filterMap(x => x)
      messages := Array.concat(messages.contents, validToolResults)

      // Continue the loop with updated messages
      Console.log("=== Continuing loop with tool results")
      await loop(messages.contents, currentTask)
    } else {
      // No more tool calls - task is complete
      Console.log2("=== No tool calls, completing task. Finish reason was:", finishReason)

      // Get final text response
      let finalText = await result->Agent__Adapters__Vercel.getText

      // Add final agent message to our internal history
      let agentMessage = Agent__Task__Message.make(
        ~role=Agent,
        ~parts=[Agent__Task__Message__Part.text(~text=finalText)],
        ~taskId=Some(currentTask.id),
      )
      //Note(Danni)-> handle errors here better
      let taskWithMessage = Agent__Task.addMessage(currentTask, agentMessage)->Result.getOrThrow
      Agent__Tasks.update(tasks, taskWithMessage)

      // Transition task to complete
      let _ = Agent__Task.transition(
        taskWithMessage,
        Complete(Some(agentMessage)),
      )->Result.map(completedTask => {
        Agent__Tasks.update(tasks, completedTask)
        Agent__EventBus.emit(eventBus, TaskStateChanged(completedTask))
      })

      Console.log("=== Agentic loop completed successfully")
    }
  }

  // Start the loop with initial messages
  Console.log("=== Calling loop for the first time")
  await loop(messages.contents, workingTask)
  Console.log("=== Agentic loop finished")
}
