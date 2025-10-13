// Agent core - main agent initialization and lifecycle

type t = {
  projectRoot: string,
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
  pluginBus: Agent__Bus__Plugin.t,
}

let initialize = async (projectRoot: string) => {
  Console.error(`Initializing agent for project: ${projectRoot}`)

  // Create plugin bus (STDIO transport)
  let pluginBus = await Agent__Bus__Plugin.make()

  // Initialize model
  let model = Agent__Bindings__VercelAI.Anthropic.claude3Sonnet()

  // Create tools
  let toolRegistry = Agent__Tools__Registry.make(projectRoot)
  let tools = Agent__Tools__Registry.toVercelTools(toolRegistry)

  Console.error(`Agent initialized with ${tools->Dict.size->Int.toString} tools`)

  {
    projectRoot,
    model,
    tools,
    pluginBus,
  }
}

let handleUserRequest = async (agent: t, request: Agent__Events.UserRequest.t) => {
  Console.error2("Received user request:", request.requestId)

  try {
    // Process request through agent loop
    let result = await Agent__Loop.processRequest(
      agent.projectRoot,
      agent.model,
      agent.tools,
      request,
      async status => {
        await agent.pluginBus->Agent__Bus__Plugin.sendStatus(
          ~requestId=request.requestId,
          ~message=status,
        )
      },
    )

    // Send response
    let message = result["message"]
    let filesChanged = result["filesChanged"]

    await agent.pluginBus->Agent__Bus__Plugin.sendResponse(
      ~requestId=request.requestId,
      ~message,
      ~filesChanged,
    )

    Console.error2("Request completed:", request.requestId)
  } catch {
  | exn => {
      let error = exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")

      Console.error3("Request failed:", request.requestId, error)

      await agent.pluginBus->Agent__Bus__Plugin.sendError(
        ~requestId=request.requestId,
        ~error,
      )
    }
  }
}

let run = async (agent: t) => {
  Console.error("Agent is running and listening for requests...")

  // Listen for user requests
  let _unsubscribe = agent.pluginBus->Agent__Bus__Plugin.onUserRequest(
    request => {
      let _ = handleUserRequest(agent, request)
    }
  )

  // Keep process alive (promise that never resolves)
  await Promise.make((_, _) => ())
}
