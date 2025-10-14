// Main agent loop - continues until LLM stops calling tools

type requestState = {
  requestId: string,
  startTime: float,
  mutable conversationHistory: array<Agent__Bindings__VercelAI.message>,
  mutable filesChanged: array<string>,
}

let buildUserContent = (request: Agent__Events.UserRequest.t): string => {
  // Build context description for the prompt
  let contextParts = []
  contextParts->Array.push(`Project Root: ${request.context.projectRoot}`)

  request.context.componentSource->Option.forEach(src => {
    contextParts->Array.push(`Component Source: ${src}`)
  })

  let contextStr = contextParts->Array.join("\n")

  `${request.userMessage}

Selected Element: ${request.selectedElement
    ->Option.map(el => `${el.component} at ${el.filePath}:${el.lineNumber->Int.toString}`)
    ->Option.getOr("None")}

Context:
${contextStr}`
}

let processRequest = async (
  _projectRoot: string,
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
  request: Agent__Events.UserRequest.t,
  onStatus: string => promise<unit>,
) => {
  let state = {
    requestId: request.requestId,
    startTime: Date.now(),
    conversationHistory: [],
    filesChanged: [],
  }

  // Add system message
  state.conversationHistory->Array.push({
    role: "system",
    content: Agent__Prompts.systemPrompt,
  })

  // Add user message
  state.conversationHistory->Array.push({
    role: "user",
    content: buildUserContent(request),
  })

  // Main loop
  let continueLoop = ref(true)
  let iteration = ref(0)
  let maxIterations = 10

  let finalText = ref("")

  while continueLoop.contents && iteration.contents < maxIterations {
    iteration := iteration.contents + 1

    await onStatus(`Processing request (step ${iteration.contents->Int.toString})`)

    // Stream from LLM
    let stream = await Agent__Bindings__VercelAI.streamText({
      model,
      messages: state.conversationHistory,
      tools: Some(tools),
      maxSteps: Some(1), // One step at a time for control
    })

    // Process stream
    let result = await Agent__StreamProcessor.process(state.requestId, stream, onStatus)

    // Save accumulated text
    let text = result["text"]
    if text != "" {
      finalText := text

      // Add assistant message to history
      state.conversationHistory->Array.push({
        role: "assistant",
        content: text,
      })
    }

    // Check termination
    let finishReason = await stream->Agent__Bindings__VercelAI.finishReason

    Console.error2("Finish reason:", finishReason)

    switch finishReason {
    | "stop" => {
        Console.error("Loop complete - no more tool calls")
        continueLoop := false
      }
    | "length" => {
        Console.error("Response exceeded maximum length")
        continueLoop := false
      }
    | _ =>
      // Continue for tool-calls or other reasons
      Console.error("Continuing loop...")
    }
  }

  if iteration.contents >= maxIterations {
    Console.error("Maximum iterations reached")
  }

  {
    "message": finalText.contents,
    "filesChanged": state.filesChanged,
  }
}
