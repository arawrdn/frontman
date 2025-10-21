S.enableJson()
// Main Agent module - entry point

// Load environment variables from .env file
let _ = AskTheLlmBindings.Dotenv.config()

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

type t = {
  projectRoot: string,
  eventBus: EventBus.t,
  tasks: Agent__Tasks.t,
  llm: Adapters.Vercel.t,
}

let make = (projectRoot: string) => {
  Console.log(`Initializing agent for project: ${projectRoot}`)
  let eventBus = EventBus.make()

  // Verify OpenAI API key is set
  let _apiKey = AskTheLlmBindings.Dotenv.getExn("OPENAI_API_KEY")
  let model = Agent__Bindings__Vercel.OpenAI.gpt4o()

  let toolRegistry = Agent__Tools__Registry.make(projectRoot)
  let llm = Agent__Adapters__Vercel.makeLLM(~model, ~toolRegistry)

  Console.log(`Agent initialized with ${toolRegistry->Array.length->Int.toString} tools`)

  {
    projectRoot,
    eventBus,
    tasks: Agent__Tasks.make(),
    llm,
  }
}

let run = (agent: t) => {
  Console.log("Agent is running and listening for domain events...")
  let unsubscribe = agent.eventBus->EventBus.on(event => {
    Console.log2("Got EventBus Event: ", event)
    switch event {
    | TaskCreated(task) => {
        Console.log("=== TaskCreated event - starting agentic loop")
        Agent__AgenticLoop.run(agent.llm, agent.tasks, agent.eventBus, task)->ignore
      }
    | TaskStateChanged(task) => {
        let statusStr = switch task.status {
        | Submitted(_) => "Submitted"
        | Working(_) => "Working"
        | InputRequired(_) => "InputRequired"
        | Completed(_) => "Completed"
        | Failed(_) => "Failed"
        | Rejected(_) => "Rejected"
        | Canceled(_) => "Canceled"
        }
        Console.log2("=== TaskStateChanged event - status:", statusStr)

        // Handle state transitions (but TaskCreated already handles initial Submitted)
        switch task.status {
        | Agent__Task__Status.Working(_) =>
          Console.log("Task working (resumed) - NOT starting loop (commented out)")
        // Agent__AgenticLoop.run(agent.llm, agent.tasks, agent.eventBus, task)->ignore
        | _ => ()
        }
      }
    | ArtifactChunkGenerated(_) => ()
    | TaskMessageAdded({task, message}) => Console.log3("Task message added", task, message)
    }
  })
  unsubscribe
}

let addTask = (agent: t, task: Agent__Task.t) => {
  Agent__Tasks.add(agent.tasks, task)
  Agent__EventBus.emit(agent.eventBus, TaskStateChanged(task))
}

// Send a message to the agent
// Creates a new task if message.taskId is None, or continues existing task if present
let sendMessage = (agent: t, message: Agent__Task__Message.t): result<Agent__Task.t, string> => {
  // Task continuation logic: if message.taskId is present, continue existing task
  // If absent, create new task implicitly
  let task = switch message->Agent__Task__Message.getTaskId {
  | Some(id) =>
    let task = Agent__Tasks.get(agent.tasks, id)->Option.getOrThrow
    Agent__Task.addMessage(task, message)->Result.map(updatedTask => {
      Agent__Tasks.update(agent.tasks, updatedTask)
      Agent__EventBus.emit(agent.eventBus, TaskMessageAdded({task: updatedTask, message}))
      updatedTask
    })

  | None =>
    Console.info("Task not found, creating new task")
    let newTask = Agent__Task.make(~history=[message])
    Agent__Tasks.add(agent.tasks, newTask)
    Agent__EventBus.emit(agent.eventBus, TaskCreated(newTask))
    Ok(newTask)
  }

  task
}

// Get a task by ID
let getTask = (agent: t, taskId: Agent__Task__Id.t): result<Agent__Task.t, string> => {
  switch Agent__Tasks.get(agent.tasks, taskId) {
  | Some(task) => Ok(task)
  | None => Error("Task not found")
  }
}
