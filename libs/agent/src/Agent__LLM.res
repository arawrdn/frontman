// LLM interface for chat interactions

type t = {
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
}

let make = (~model, ~tools) => {
  {model, tools}
}

let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  // Convert messages using adapter
  let vercelMessages = Agent__Adapters__Vercel.messagesToVercel(messages)

  // Call LLM
  let result = await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: Some(llm.tools),
    maxSteps: None,
  })

  await result->Agent__Bindings__VercelAI.text
}
