// Task module - state machine and task entity
module Agent = Agent__Types.Agent
module Task = Agent__Types.Task
module Status = Agent__Types.Status

let addNew = (agent: Agent.t, task: Task.t) => {
  agent.tasks.contents->Dict.set(Agent__Id.toString(task.id), task)
  Agent__EventBus.emit(agent.eventBus, TaskStateChanged(task))
}

let transition = (task: Task.t, agent: Agent.t, event: Status.event): result<unit, string> => {
  switch Status.transition(task.status.contents, event) {
  | Ok(newStatus) => {
      task.status := newStatus
      Agent__EventBus.emit(agent.eventBus, TaskStateChanged(task))
      Ok()
    }
  | Error(msg) => Error(msg)
  }
}

// Queries
let isTerminal = (task: Task.t): bool => Status.isTerminal(task.status.contents)
let getStatus = (task: Task.t): Status.t => task.status.contents
let getId = (task: Task.t): Agent__Id.t => task.id
let getHistory = (task: Task.t): array<Agent__Message.t> => task.history.contents
let getArtifacts = (task: Task.t): array<Agent__Artifact.t> => task.artifacts.contents

// Mutations
let addMessage = (task: Task.t, agent: Agent.t, message: Agent__Message.t): unit => {
  task.history.contents->Array.push(message)->ignore
  agent.eventBus->Agent__EventBus.emit(
    TaskMessageAdded({
      task,
      message,
    }),
  )
}

let addArtifact = (task: Task.t, artifact: Agent__Artifact.t): unit => {
  task.artifacts.contents->Array.push(artifact)->ignore
}
