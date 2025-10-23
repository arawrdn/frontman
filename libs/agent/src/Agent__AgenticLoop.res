// Agentic loop - handles a single LLM iteration
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

module Adapter = Agent__Adapters__Vercel

// Run a single iteration: call LLM with current history and add response messages
let runIteration = async (
  llm: Adapter.t,
  executeCommand: (Agent__Task__Id.t, Agent__Task__Commands.t) => result<Agent__Task.t, string>,
  task: Agent__Task.t,
) => {
  Console.log("=== Running single LLM iteration")

  let history = task->Agent__Task.getHistory
  Console.log(`=== Calling LLM with ${history->Array.length->Int.toString} messages`)

  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  await Adapter.processAsyncIterable(stream, async event => {
    switch event {
    | TextDelta({textDelta}) => Console.log(textDelta)
    | ToolCall({toolName, _}) => Console.log(`\nCalling tool: ${toolName}`)
    | _ => ()
    }
  })

  // Add LLM generated messages to task history
  let response = await result->Adapter.getResponse
  Console.log2("Response messages count:", response.messages->Array.length)

  // Convert ALL messages (assistant + tool) to domain format and add to task
  response.messages->Array.forEach(vercelMsg => {
    let domainMessage = Adapter.messageFromVercel(vercelMsg)->Option.getOrThrow
    switch executeCommand(task.id, Agent__Task__Commands.AddMessage({message: domainMessage})) {
    | Ok(_) => ()
    | Error(e) => Console.error(`Failed to add message: ${e}`)
    }
  })

  Console.log("=== Iteration complete")
}
