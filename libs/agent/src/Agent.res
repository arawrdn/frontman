// Main Agent module - entry point

// Load environment variables from .env file
let _ = AskTheLlmBindings.Dotenv.config()

module Bindings = AskTheLlmBindings

let make = projectRoot => {
  Agent__Types.Agent.make(projectRoot)
}

let run = (agent: Agent__Types.Agent.t) => {
  let shutdown = agent.eventBus->Agent__EventBus.on((event: Agent__Types.EventBus.events) => {
    switch event {
    | TaskStateChanged(task) =>
      switch task.status.contents {
      | Agent__Types.Status.Submitted(_) => {
          Console.error("Task submitted, starting agentic loop...")
          Agent__AgenticLoop.run(agent, task)->ignore
        }
      | Agent__Types.Status.Working(_) =>
        Console.error("Task working (resumed), starting agentic loop...")
      // Agent__AgenticLoop.run(agent, task)->ignore
      | _ => ()
      }
    | ArtifactChunkGenerated(_) => ()
    | TaskMessageAdded({task, message}) => Console.log3("Task message added", task, message)
    }
  })
  Console.error("Agent is running and listening for domain events...")
  shutdown
}

// Send a message to the agent
// Creates a new task if message.taskId is None, or continues existing task if present
let sendMessage = (agent: Agent__Types.Agent.t, message: Agent__Message.t): result<
  (Agent__Id.t, Agent__Types.Task.t),
  string,
> => {
  // Task continuation logic: if message.taskId is present, continue existing task
  // If absent, create new task implicitly
  let taskId = switch message.taskId {
  | Some(id) => id
  | None => Agent__Id.make()
  }

  let config = {
    Agent__MessageHandler.taskId: Some(taskId),
    contextId: message.contextId,
    userMessage: message,
  }

  let task = Agent__MessageHandler.processMessage(agent, config)

  // Return the task
  Ok((taskId, task))
}

// Get a task by ID
let getTask = (agent: Agent__Types.Agent.t, taskId: Agent__Id.t): result<
  Agent__Types.Task.t,
  string,
> => {
  switch agent.tasks.contents->Dict.get(Agent__Id.toString(taskId)) {
  | Some(task) => Ok(task)
  | None => Error("Task not found")
  }
}

// Cancel a task
let cancelTask = (
  agent: Agent__Types.Agent.t,
  taskId: Agent__Id.t,
  ~reason: option<string>=None,
): result<Agent__Types.Task.t, string> => {
  switch agent.tasks.contents->Dict.get(Agent__Id.toString(taskId)) {
  | Some(task) => {
      // Create cancellation message if reason provided
      let cancelMessage = switch reason {
      | Some(text) =>
        Some(
          Agent__Message.make(
            ~role=Agent,
            ~parts=[Agent__Part.text(~text)],
            ~taskId=Some(taskId),
            ~contextId=task.contextId,
          ),
        )
      | None => None
      }

      switch task->Agent__Task.transition(agent, Cancel(cancelMessage)) {
      | Ok() => {
          // Emit TaskStateChanged event
          agent.eventBus->Agent__EventBus.emit(TaskStateChanged(task))
          Ok(task)
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
module Message = Agent__Message
module Part = Agent__Part
module Artifact = Agent__Artifact
module Id = Agent__Id
