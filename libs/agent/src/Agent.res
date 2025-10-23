// Main Agent module - entry point
S.enableJson()

module Bindings = AskTheLlmBindings

module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}
module Adapters = {
  module Vercel = Agent__Adapters__Vercel
}
module StreamProcessor = Agent__StreamProcessor
module AgenticLoop = Agent__AgenticLoop
module Task = Agent__Task
module TaskMessage = Agent__Task__Message
module Part = Agent__Task__Message__Part
module Artifact = Agent__Artifact
module Id = Agent__Id
module TaskId = Agent__Task__Id
module EventBus = Agent__EventBus
module TaskCommands = Agent__Task__Commands
module TaskEvents = Agent__Task__Events

type t = {
  projectRoot: string,
  eventBus: EventBus.t,
  tasks: Agent__Tasks.t,
  llm: Adapters.Vercel.t,
}
type config = {
  projectRoot: string,
  apiKey: string,
}

let make = (config: config) => {
  Console.log(`Initializing agent for project: ${config.projectRoot}`)
  let eventBus = EventBus.make()

  let model = Agent__Bindings__Vercel.OpenAI.gpt4o(config.apiKey)

  let toolRegistry = Agent__Tools__Registry.make(config.projectRoot)
  let llm = Agent__Adapters__Vercel.makeLLM(~model, ~toolRegistry)

  Console.log(`Agent initialized with ${toolRegistry->Array.length->Int.toString} tools`)

  {
    projectRoot: config.projectRoot,
    eventBus,
    tasks: Agent__Tasks.make(),
    llm,
  }
}

// Execute a task command using Command → Decide → Events → Evolve
let executeTaskCommand = (agent: t, taskId: Agent__Task__Id.t, cmd: TaskCommands.t): result<
  Agent__Task.t,
  string,
> => {
  let currentTask = Agent__Tasks.get(agent.tasks, taskId)

  Agent__Task.decide(currentTask, cmd)->Result.map(events => {
    let newTask = events->List.reduce(currentTask, Agent__Task.evolve)

    switch newTask {
    | Some(task) => {
        Agent__Tasks.update(agent.tasks, task)

        // Emit EventBus events for each domain event
        events->List.forEach(event => {
          switch event {
          | Created(_) => agent.eventBus->EventBus.emit(TaskCreated(task))
          | ProcessingStarted(_)
          | Completed(_)
          | Failed(_)
          | Canceled(_)
          | InputRequested(_)
          | Resumed(_)
          | Rejected(_) =>
            agent.eventBus->EventBus.emit(TaskStateChanged(task))
          | MessageAdded({message}) =>
            agent.eventBus->EventBus.emit(TaskMessageAdded({task, message}))
          | ArtifactAdded(_) => () // No EventBus event for artifacts yet
          }
        })

        task
      }
    | None =>
      JsError.throwWithMessage("Internal error: evolve returned None after decide succeeded")
    }
  })
}

let run = (agent: t) => {
  Console.log("Agent is running and listening for domain events...")
  let unsubscribe = agent.eventBus->EventBus.on(event => {
    Console.log2("Got EventBus Event: ", event)
    switch event {
    | TaskCreated(task) => {
        Console.log("=== TaskCreated event - starting agentic loop")
        Agent__AgenticLoop.run(
          agent.llm,
          (taskId, cmd) => executeTaskCommand(agent, taskId, cmd),
          task,
        )->ignore
      }
    | TaskStateChanged(task) => {
        Console.log2("=== TaskStateChanged event - status:", task.status->Task.Status.toString)

        // Handle state transitions (but TaskCreated already handles initial Submitted)
        switch task.status {
        | Agent__Task.Status.Working(_) =>
          Console.log("Task working (resumed) - NOT starting loop (commented out)")
        // Agent__AgenticLoop.run(agent.llm, (taskId, cmd) => executeTaskCommand(agent, taskId, cmd), task)->ignore
        | _ => ()
        }
      }
    | ArtifactChunkGenerated(_) => ()
    | TaskMessageAdded({task, message}) => Console.log3("Task message added", task, message)
    }
  })
  unsubscribe
}

// Send a message to the agent
// Creates a new task if message.taskId is None, or continues existing task if present
let sendMessage = (agent: t, message: Agent__Task__Message.t): result<Agent__Task.t, string> => {
  switch message->Agent__Task__Message.getTaskId {
  | Some(id) => executeTaskCommand(agent, id, TaskCommands.AddMessage({message: message}))
  | None => {
      let newId = Agent__Id.make()
      executeTaskCommand(agent, newId, TaskCommands.Create({initialMessage: message}))
    }
  }
}
