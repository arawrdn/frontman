// Message processing with event streaming

let processMessage = (
  tasks: Agent__Tasks.t,
  eventBus: Agent__EventBus.t,
  ~taskId: option<Agent__Task__Id.t>,
  ~contextId: option<Agent__Context__Id.t>,
  ~message: Agent__Task__Message.t,
) => {
  // Get or create task
  let taskId = taskId->Option.getOrThrow
  let (task, isNewTask) = switch Agent__Tasks.get(tasks, taskId) {
  | Some(existingTask) => (existingTask, false)
  | None =>
    Console.error("Task not found, creating new task")
    let newTask = Agent__Task.makeWithId(~id=taskId, ~contextId)
    Agent__Tasks.add(tasks, newTask)
    Agent__EventBus.emit(eventBus, TaskStateChanged(newTask))
    (newTask, true)
  }

  let updatedTask = Agent__Task.addMessage(task, message)
  Agent__Tasks.update(tasks, updatedTask)

  if isNewTask {
    Agent__EventBus.emit(eventBus, TaskMessageAdded({task: updatedTask, message}))
  }
  Agent__EventBus.emit(eventBus, TaskStateChanged(updatedTask))

  let finalTask = switch Agent__Task.getStatus(updatedTask) {
  | InputRequired(_) =>
    switch Agent__Task.transition(updatedTask, Agent__Task__Status.Resume(Some(message))) {
    | Ok(transitioned) => {
        Agent__Tasks.update(tasks, transitioned)
        transitioned
      }
    | Error(_) => updatedTask
    }
  | _ => updatedTask
  }

  // Return the task so the caller can start the agentic loop
  finalTask
}
