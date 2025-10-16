// Message processing with event streaming

module Task = Agent__Types.Task
type processMessageConfig = {
  taskId: option<Agent__Id.t>,
  contextId: option<Agent__Id.t>,
  userMessage: Agent__Message.t,
}

let processMessage = (agent: Agent__Types.Agent.t, config: processMessageConfig) => {
  let {taskId, contextId, userMessage} = config

  // Get or create task
  let taskId = taskId->Option.getOrThrow
  let task = switch agent.tasks.contents->Dict.get(Agent__Id.toString(taskId)) {
  | Some(existingTask) => existingTask
  | None =>
    Console.error("Task not found, creating new task")
    let newTask = Task.makeWithId(~id=taskId, ~contextId)
    Agent__Task.addNew(agent, newTask)
    newTask
  }

  task->Agent__Task.addMessage(agent, userMessage)

  // Transition task status
  let _ = switch task->Agent__Task.getStatus {
  | InputRequired(_) =>
    task->Agent__Task.transition(agent, Agent__Types.Status.Resume(Some(userMessage)))
  | _ => Ok()
  }

  // Return the task so the caller can start the agentic loop
  task
}
