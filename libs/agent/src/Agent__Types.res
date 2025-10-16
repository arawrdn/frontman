module Timestamp: {
  type t
  let now: unit => t
  let toString: t => string
} = {
  type t = Timestamp(string)

  let now = () => {
    let iso = %raw(`new Date().toISOString()`)
    Timestamp(iso)
  }

  let toString = (Timestamp(str): t): string => str
}
module Status = {
  // Each status is a distinct record type with only valid fields
  type submitted = {timestamp: Timestamp.t}

  type working = {
    timestamp: Timestamp.t,
    message: option<Agent__Message.t>,
  }

  type inputRequired = {
    timestamp: Timestamp.t,
    message: Agent__Message.t, // Required - must have question
  }

  type completed = {
    timestamp: Timestamp.t,
    message: option<Agent__Message.t>,
  }

  type failed = {
    timestamp: Timestamp.t,
    message: Agent__Message.t, // Required - must have error
  }

  type rejected = {
    timestamp: Timestamp.t,
    message: Agent__Message.t, // Required - must have reason
  }

  type canceled = {
    timestamp: Timestamp.t,
    message: option<Agent__Message.t>, // Optional cancellation reason
  }

  // Status union
  type t =
    | Submitted(submitted)
    | Working(working)
    | InputRequired(inputRequired)
    | Completed(completed)
    | Failed(failed)
    | Rejected(rejected)
    | Canceled(canceled)

  // Status transition events
  type event =
    | StartProcessing(option<Agent__Message.t>)
    | RequestInput(Agent__Message.t)
    | Resume(option<Agent__Message.t>)
    | Complete(option<Agent__Message.t>)
    | Fail(Agent__Message.t)
    | Reject(Agent__Message.t)
    | Cancel(option<Agent__Message.t>)

  // Define legal status transitions
  let transition = (current: t, event: event): result<t, string> => {
    switch (current, event) {
    // From Submitted
    | (Submitted(_), StartProcessing(message)) => Ok(Working({timestamp: Timestamp.now(), message}))
    | (Submitted(_), Reject(message)) => Ok(Rejected({timestamp: Timestamp.now(), message}))
    | (Submitted(_), Cancel(message)) => Ok(Canceled({timestamp: Timestamp.now(), message}))

    // From Working
    | (Working(_), Complete(message)) => Ok(Completed({timestamp: Timestamp.now(), message}))
    | (Working(_), RequestInput(message)) =>
      Ok(InputRequired({timestamp: Timestamp.now(), message}))
    | (Working(_), Fail(message)) => Ok(Failed({timestamp: Timestamp.now(), message}))
    | (Working(_), Cancel(message)) => Ok(Canceled({timestamp: Timestamp.now(), message}))

    // From InputRequired
    | (InputRequired(_), Resume(message)) => Ok(Working({timestamp: Timestamp.now(), message}))
    | (InputRequired(_), Fail(message)) => Ok(Failed({timestamp: Timestamp.now(), message}))
    | (InputRequired(_), Cancel(message)) => Ok(Canceled({timestamp: Timestamp.now(), message}))

    // Terminal statuses cannot transition
    | (Completed(_), _) => Error("Cannot transition from completed status")
    | (Failed(_), _) => Error("Cannot transition from failed status")
    | (Rejected(_), _) => Error("Cannot transition from rejected status")
    | (Canceled(_), _) => Error("Cannot transition from canceled status")

    // All other transitions are illegal
    | (_, _) => Error("Illegal status transition")
    }
  }

  // Check if status is terminal
  let isTerminal = (status: t): bool => {
    switch status {
    | Completed(_) | Failed(_) | Rejected(_) | Canceled(_) => true
    | _ => false
    }
  }

  // Initial status constructor
  let initial = (): t => {
    Submitted({timestamp: Timestamp.now()})
  }

  // Get current message from status (if any)
  let getMessage = (status: t): option<Agent__Message.t> => {
    switch status {
    | Submitted(_) => None
    | Working({message}) => message
    | InputRequired({message}) => Some(message)
    | Completed({message}) => message
    | Failed({message}) => Some(message)
    | Rejected({message}) => Some(message)
    | Canceled({message}) => message
    }
  }

  // Get timestamp from status
  let getTimestamp = (status: t): Timestamp.t => {
    switch status {
    | Submitted({timestamp}) => timestamp
    | Working({timestamp}) => timestamp
    | InputRequired({timestamp}) => timestamp
    | Completed({timestamp}) => timestamp
    | Failed({timestamp}) => timestamp
    | Rejected({timestamp}) => timestamp
    | Canceled({timestamp}) => timestamp
    }
  }
}
module Task = {
  type t = {
    id: Agent__Id.t,
    contextId: option<Agent__Id.t>,
    status: ref<Status.t>,
    history: ref<array<Agent__Message.t>>,
    artifacts: ref<array<Agent__Artifact.t>>,
    metadata: option<Dict.t<JSON.t>>,
  }

  // Constructors
  let make = (~contextId=None, ~metadata=None): t => {
    {
      id: Agent__Id.make(),
      contextId,
      status: ref(Status.initial()),
      history: ref([]),
      artifacts: ref([]),
      metadata,
    }
  }

  let makeWithId = (~id, ~contextId=None, ~metadata=None): t => {
    {
      id,
      contextId,
      status: ref(Status.initial()),
      history: ref([]),
      artifacts: ref([]),
      metadata,
    }
  }
}
module EventBus = {
  type artifactChunkGenerated = {
    taskId: Agent__Id.t,
    contextId: option<Agent__Id.t>,
    artifact: Agent__Artifact.t,
    isComplete: bool,
  }

  type taskMessageAdded = {
    task: Task.t,
    message: Agent__Message.t,
  }

  type events =
    | TaskStateChanged(Task.t)
    | ArtifactChunkGenerated(artifactChunkGenerated)
    | TaskMessageAdded(taskMessageAdded)

  type t = {handlers: ref<array<events => unit>>}

  let make = () => {
    handlers: ref([]),
  }
}

// ============ Agent ============

module Agent = {
  type t = {
    projectRoot: string,
    model: Agent__Bindings__VercelAI.languageModel,
    tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
    eventBus: EventBus.t,
    tasks: ref<Dict.t<Task.t>>,
    llm: Agent__LLM.t,
  }

  let make = (projectRoot: string) => {
    Console.log(`Initializing agent for project: ${projectRoot}`)
    let eventBus = EventBus.make()

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
