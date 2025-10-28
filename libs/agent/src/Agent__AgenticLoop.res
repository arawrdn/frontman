// Agentic loop - handles a single LLM iteration
// Follows the AI SDK manual agent loop pattern:
// https://ai-sdk.dev/cookbook/node/manual-agent-loop

module Adapter = Agent__Adapters__Vercel

// Run a single iteration: call LLM with current history and return commands
let runIteration = async (
  llm: Adapter.t,
  task: Agent__Task.t,
  ~emitEvent: Agent__EventBus.events => unit,
): array<Agent__Task.cmd> => {
  let history = task->Agent__Task.getHistory
  Console.log(`=== Calling LLM with ${history->Array.length->Int.toString} messages`)

  let result = await Adapter.streamText(llm, history)
  let stream = result->Adapter.getFullStream

  // Process stream and emit ALL events to EventBus
  await Adapter.processAsyncIterable(stream, async event => {
    Console.log("stream event:")
    Console.dir(event, ~options={depth: Null})
    emitEvent(StreamEvent(task, event))
  })

  // Get LLM generated messages
  let response = await result->Adapter.getResponse

  // Convert messages to domain commands, filtering out None (tool results we don't want)
  let commands =
    response.messages
    ->Array.filterMap(vercelMsg => Adapter.messageFromVercel(vercelMsg, task.id))
    ->Array.map(domainMessage => {
      Agent__Task.AddMessage({task, message: domainMessage})
    })

  Console.log("=== Iteration complete")
  commands
}
