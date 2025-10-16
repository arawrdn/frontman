// Agentic loop - handles the continuous LLM interaction cycle with tool execution

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
let rec run = async (agent: Agent__Types.Agent.t, task: Agent__Types.Task.t) => {
  let history = task->Agent__Task.getHistory
  //TODO(Danni): refactor this, it can be simpler
  let stream = await agent.llm->Agent__LLM.streamText(history)
  let result = await Agent__StreamProcessor.process("", stream)
  if result.hasToolCalls {
    Console.log("Processing tool calls...")
    let _ = await result.toolCalls
    ->Array.map(async toolCall => {
      let toolName = toolCall.toolName
      let args = toolCall.input->Option.getOr(JSON.Encode.null)
      Console.log2(`Executing tool: ${toolName}`, args)
      let result = await executeTool(agent, toolName, args)

      switch result {
      | Ok(output) => {
          Console.error2(`Tool ${toolName} succeeded:`, output)

          let toolResultMessage = Agent__Message.make(
            ~role=Agent,
            ~parts=[Agent__Part.text(~text=output)],
            ~taskId=Some(task.id),
            ~contextId=task.contextId,
          )

          task->Agent__Task.addMessage(agent, toolResultMessage)
          Ok((toolName, output))
        }
      | Error(err) => {
          Console.error2(`Tool ${toolName} failed:`, err)
          Error((toolName, err))
        }
      }
    })
    ->Promise.all

    // Loop back: call LLM again with tool results
    await run(agent, task)
  } else {
    Console.error("No tool calls, completing task")
    let agentMessage = Agent__Message.make(
      ~role=Agent,
      ~parts=[Agent__Part.text(~text=result.text)],
      ~taskId=Some(task.id),
      ~contextId=task.contextId,
    )
    task->Agent__Task.addMessage(agent, agentMessage)
    let _ = task->Agent__Task.transition(agent, Complete(Some(agentMessage)))
  }
}
