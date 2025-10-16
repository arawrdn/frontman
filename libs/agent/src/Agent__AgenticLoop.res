// Agentic loop - handles the continuous LLM interaction cycle with tool execution
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

// Execute a single tool call
let executeTool = async (agent: Agent__Types.Agent.t, toolName: string, args: JSON.t): result<
  string,
  string,
> => {
  // Look up tool in registry
  switch agent.tools->Dict.get(toolName) {
  | Some(toolDef) =>
    try {
      let result = await toolDef.execute(args)
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
  | None => Error(`Tool ${toolName} not found in registry`)
  }
}

// Main agentic loop: keep calling LLM while it needs tool calls
let run = async (agent: Agent__Types.Agent.t, task: Agent__Types.Task.t) => {
  // Get current message history and convert to Vercel format
  let history = task->Agent__Task.getHistory
  let messages = ref(Agent__Adapters__Vercel.messagesToVercel(history))

  // Start the agent loop
  let rec loop = async (vercelMessages: array<Agent__Bindings__VercelAI.message>) => {
    // Call LLM with current message history
    let result = await agent.llm->Agent__LLM.streamTextWithVercelMessages(vercelMessages)

    // Stream the response (for user updates - optional but recommended)
    let stream = result->Agent__Bindings__VercelAI.fullStream

    await Agent__StreamProcessor.processAsyncIterable(stream, async event => {
      switch event {
      | TextDelta({textDelta}) => Console.log(textDelta)
      | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
      | _ => ()
      }
    })

    // Add LLM generated messages to the message history (CRITICAL!)
    let response = await result->Agent__Bindings__VercelAI.response
    messages := Array.concat(messages.contents, response.messages)

    // Check finish reason to decide whether to continue
    let finishReason = await result->Agent__Bindings__VercelAI.finishReason

    if finishReason == "tool-calls" {
      // Get tool calls and execute them
      let toolCalls = await result->Agent__Bindings__VercelAI.toolCalls

      Console.log("Processing tool calls...")

      // Execute all tool calls and collect results
      let toolResultMessages = await toolCalls
      ->Array.map(async toolCall => {
        let toolName = toolCall.toolName
        let args = toolCall.args
        Console.log2(`Executing tool: ${toolName}`, args)

        let toolResult = await executeTool(agent, toolName, args)

        switch toolResult {
        | Ok(output) => {
            Console.error2(`Tool ${toolName} succeeded:`, output)

            // Create tool result message in Vercel format
            Some(
              Agent__Adapters__Vercel.makeToolResultMessage(
                toolCall.toolCallId,
                toolName,
                output,
              ),
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
      await loop(messages.contents)
    } else {
      // No more tool calls - task is complete
      Console.error("No tool calls, completing task")

      // Get final text response
      let finalText = await result->Agent__Bindings__VercelAI.text

      // Add final agent message to our internal history
      let agentMessage = Agent__Message.make(
        ~role=Agent,
        ~parts=[Agent__Part.text(~text=finalText)],
        ~taskId=Some(task.id),
        ~contextId=task.contextId,
      )
      task->Agent__Task.addMessage(agent, agentMessage, false)

      // Transition task to complete
      let _ = task->Agent__Task.transition(agent, Complete(Some(agentMessage)))
    }
  }

  // Start the loop with initial messages
  await loop(messages.contents)
}
