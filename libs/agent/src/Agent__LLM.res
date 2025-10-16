// LLM interface for chat interactions

type t = {
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
}

let make = (~model, ~tools) => {
  {model, tools}
}

let streamText = async (
  llm: t,
  messages: array<Agent__Message.t>,
): Agent__Bindings__VercelAI.streamTextResult => {
  let vercelMessages = Agent__Adapters__Vercel.messagesToVercel(messages)
  await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: Some(llm.tools),
    maxSteps: None, // Manual control
  })
}

// Keep existing chat function for backward compatibility
let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  let result = await streamText(llm, messages)
  await result->Agent__Bindings__VercelAI.text
}
