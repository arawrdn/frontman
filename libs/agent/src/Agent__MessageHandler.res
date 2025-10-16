// Message processing with event streaming

type processMessageConfig = {
  taskId: option<Agent__Id.t>,
  contextId: option<Agent__Id.t>,
  userMessage: Agent__Message.t,
  onTaskUpdate: (Agent__Id.t, Agent__Task.t) => unit,
}

let processMessage = (
  agent: Agent__Types.Agent.t,
  config: processMessageConfig,
) => {
  let {taskId, contextId, userMessage, onTaskUpdate} = config

  // Get or create task
  let task = switch taskId {
  | Some(id) =>
    switch agent.tasks.contents->Dict.get(Agent__Id.toString(id)) {
    | Some(existingTask) => existingTask
    | None =>
      Console.error("Task not found, creating new task")
      let newTask = Agent__Task.makeWithId(~id, ~contextId)
      agent.tasks.contents->Dict.set(Agent__Id.toString(id), newTask)
      newTask
    }
  | None =>
    let newTask = Agent__Task.make(~contextId)
    agent.tasks.contents->Dict.set(Agent__Id.toString(newTask.id), newTask)
    newTask
  }

  // Add user message to history
  task->Agent__Task.addMessage(userMessage)

  // Transition task status
  let _ = switch task->Agent__Task.getStatus {
  | Submitted(_) =>
    task->Agent__Task.transition(StartProcessing(None))
  | InputRequired(_) =>
    task->Agent__Task.transition(Resume(None))
  | _ => Ok()
  }

  // Emit TaskStateChanged event
  agent.eventBus->Agent__EventBus.emit(
    TaskStateChanged({
      taskId: task.id,
      contextId: task.contextId,
    }),
  )

  // Notify middleware
  onTaskUpdate(task.id, task)

  // Build LLM conversation from task history
  let history = task->Agent__Task.getHistory

  // Stream LLM response
  let processStream = async () => {
    try {
      let response = await agent.llm->Agent__LLM.chat(history)

      // Create agent message with response
      let agentMessage = Agent__Message.make(
        ~role=Agent,
        ~parts=[Agent__Part.text(~text=response)],
        ~taskId=Some(task.id),
        ~contextId=task.contextId,
      )

      // Add to history
      task->Agent__Task.addMessage(agentMessage)

      // Emit TaskMessageAdded event
      agent.eventBus->Agent__EventBus.emit(
        TaskMessageAdded({
          taskId: task.id,
          message: agentMessage,
        }),
      )

      // Complete task
      let _ = task->Agent__Task.transition(Complete(Some(agentMessage)))

      // Emit TaskStateChanged event
      agent.eventBus->Agent__EventBus.emit(
        TaskStateChanged({
          taskId: task.id,
          contextId: task.contextId,
        }),
      )

      // Final notification
      onTaskUpdate(task.id, task)
    } catch {
    | error =>
      Console.error2("Error processing message:", error)
      let errorMessage = Agent__Message.make(
        ~role=Agent,
        ~parts=[Agent__Part.text(~text="Error processing request")],
        ~taskId=Some(task.id),
        ~contextId=task.contextId,
      )

      let _ = task->Agent__Task.transition(Fail(errorMessage))

      agent.eventBus->Agent__EventBus.emit(
        TaskStateChanged({
          taskId: task.id,
          contextId: task.contextId,
        }),
      )

      onTaskUpdate(task.id, task)
    }
  }

  processStream()->ignore
}
