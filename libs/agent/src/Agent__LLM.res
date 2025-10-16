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
  
  let params = {
    Agent__Bindings__VercelAI.model: llm.model,
    messages: vercelMessages,
    tools: llm.tools,
  }
  
  await Agent__Bindings__VercelAI.streamText(params)
}

// Stream text with Vercel messages directly (for manual loop control)
let streamTextWithVercelMessages = async (
  llm: t,
  messages: array<Agent__Bindings__VercelAI.message>,
): Agent__Bindings__VercelAI.streamTextResult => {
  let params = {
    Agent__Bindings__VercelAI.model: llm.model,
    messages,
    tools: llm.tools,
  }
  
  await Agent__Bindings__VercelAI.streamText(params)
}

// Keep existing chat function for backward compatibility
let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  let result = await streamText(llm, messages)
  await result->Agent__Bindings__VercelAI.text
}
