// ============ Agent ============

module Agent = {
  type t = {
    projectRoot: string,
    model: Agent__Bindings__VercelAI.languageModel,
    tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
    eventBus: Agent__EventBus.t,
    tasks: ref<Dict.t<Agent__Task.t>>,
    llm: Agent__LLM.t,
  }

  let make = (projectRoot: string) => {
    Console.log(`Initializing agent for project: ${projectRoot}`)
    let eventBus = Agent__EventBus.make()

    // Verify OpenAI API key is set
    let _apiKey = AskTheLlmBindings.Dotenv.getExn("OPENAI_API_KEY")
    let model = Agent__Bindings__VercelAI.OpenAI.gpt4o()

    let toolRegistry = Agent__Tools__Registry.make(projectRoot)
    let tools = Agent__Adapters__Vercel.toVercelTools(toolRegistry)

    // Debug: Check tool structure
    tools
    ->Dict.toArray
    ->Array.forEach(((toolName, tool)) => {
      Console.error2(`Tool ${toolName}:`, tool.inputSchema)
    })

    // Note: Don't use Console.debug/log here - stdout is used for IPC
    Console.log(`Agent initialized with ${tools->Dict.size->Int.toString} tools`)

    let llm = Agent__LLM.make(~model, ~tools)

    {
      projectRoot,
      model,
      tools,
      eventBus,
      tasks: ref(Dict.make()),
      llm,
    }
  }
}
