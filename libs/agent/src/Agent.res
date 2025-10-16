// Main Agent module - entry point

// Load environment variables from .env file
let _ = AskTheLlmBindings.Dotenv.config()

module Bindings = AskTheLlmBindings

type t = {
  projectRoot: string,
  eventBus: Agent__EventBus.t,
  tasks: Agent__Tasks.t,
  llm: Agent__Adapters__Vercel.t,
}

let make = (projectRoot: string) => {
  Console.log(`Initializing agent for project: ${projectRoot}`)
  let eventBus = Agent__EventBus.make()

  // Verify OpenAI API key is set
  let _apiKey = AskTheLlmBindings.Dotenv.getExn("OPENAI_API_KEY")
  let model = Agent__Bindings__VercelAI.OpenAI.gpt4o()

  let toolRegistry = Agent__Tools__Registry.make(projectRoot)
  let llm = Agent__Adapters__Vercel.makeLLM(~model, ~toolRegistry)

  // Note: Don't use Console.debug/log here - stdout is used for IPC
  Console.log(`Agent initialized with ${toolRegistry->Array.length->Int.toString} tools`)

  {
    projectRoot,
    eventBus,
    tasks: Agent__Tasks.make(),
    llm,
  }
}

let run = (agent: t) => {
  let shutdown = agent.eventBus->Agent__EventBus.on((event: Agent__EventBus.events) => {
    switch event {
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

        switch task.status {
        | Agent__Task__Status.Submitted(_) => {
            Console.log("Task submitted, starting agentic loop...")
            Agent__AgenticLoop.run(agent.llm, agent.tasks, agent.eventBus, task)->ignore
          }
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
  Console.log("Agent is running and listening for domain events...")
  shutdown
}

let addTask = (agent: t, task: Agent__Task.t) => {
  Agent__Tasks.add(agent.tasks, task)
  Agent__EventBus.emit(agent.eventBus, TaskStateChanged(task))
}

// Send a message to the agent
// Creates a new task if message.taskId is None, or continues existing task if present
let sendMessage = (agent: t, message: Agent__Task__Message.t): result<
  (Agent__Task__Id.t, Agent__Task.t),
  string,
> => {
  // Task continuation logic: if message.taskId is present, continue existing task
  // If absent, create new task implicitly
  let taskId = switch message.taskId {
  | Some(id) => id
  | None => Agent__Task__Id.make()
  }

  let task = Agent__MessageHandler.processMessage(
    agent.tasks,
    agent.eventBus,
    ~taskId=Some(taskId),
    ~contextId=message.contextId,
    ~message,
  )

  // Return the task
  Ok((taskId, task))
}

// Get a task by ID
let getTask = (agent: t, taskId: Agent__Task__Id.t): result<Agent__Task.t, string> => {
  switch Agent__Tasks.get(agent.tasks, taskId) {
  | Some(task) => Ok(task)
  | None => Error("Task not found")
  }
}

// Cancel a task
let cancelTask = (agent: t, taskId: Agent__Task__Id.t, ~reason: option<string>=None): result<
  Agent__Task.t,
  string,
> => {
  switch Agent__Tasks.get(agent.tasks, taskId) {
  | Some(task) => {
      // Create cancellation message if reason provided
      let cancelMessage = switch reason {
      | Some(text) =>
        Some(
          Agent__Task__Message.make(
            ~role=Agent,
            ~parts=[Agent__Part.text(~text)],
            ~taskId=Some(taskId),
            ~contextId=task.contextId,
          ),
        )
      | None => None
      }

      switch Agent__Task.transition(task, Cancel(cancelMessage)) {
      | Ok(updatedTask) => {
          // Update in registry
          Agent__Tasks.update(agent.tasks, updatedTask)
          // Emit TaskStateChanged event
          Agent__EventBus.emit(agent.eventBus, TaskStateChanged(updatedTask))
          Ok(updatedTask)
        }
      | Error(msg) => Error(msg)
      }
    }
  | None => Error("Task not found")
  }
}

module Events = Agent__Events
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}
module Adapters = {
  module Vercel = Agent__Adapters__Vercel
}
module StreamProcessor = Agent__StreamProcessor
module MessageHandler = Agent__MessageHandler
module AgenticLoop = Agent__AgenticLoop
module Task = Agent__Task
module TaskMessage = Agent__Task__Message
module Part = Agent__Part
module Artifact = Agent__Artifact
module Id = Agent__Id
module TaskId = Agent__Task__Id
module ContextId = Agent__Context__Id
