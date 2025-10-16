// Task aggregate root - immutable
module Status = Agent__Task__Status

// Domain-specific ID type alias
type taskId = Agent__Task__Id.t

type t = {
  id: taskId,
  contextId: option<Agent__Context__Id.t>,
  status: Status.t,
  history: array<Agent__Task__Message.t>,
  artifacts: array<Agent__Artifact.t>,
  metadata: option<Dict.t<JSON.t>>,
}

// Constructors
let make = (~contextId=None, ~metadata=None): t => {
  {
    id: Agent__Id.make(),
    contextId,
    status: Status.initial(),
    history: [],
    artifacts: [],
    metadata,
  }
}

let makeWithId = (~id, ~contextId=None, ~metadata=None): t => {
  {
    id,
    contextId,
    status: Status.initial(),
    history: [],
    artifacts: [],
    metadata,
  }
}

// State transitions - return new Task
let transition = (task: t, event: Status.event): result<t, string> => {
  Status.transition(task.status, event)->Result.map(newStatus => {...task, status: newStatus})
}

// Mutations - return new Task
let addMessage = (task: t, message: Agent__Task__Message.t): t => {
  {...task, history: Array.concat(task.history, [message])}
}

let addArtifact = (task: t, artifact: Agent__Artifact.t): t => {
  {...task, artifacts: Array.concat(task.artifacts, [artifact])}
}

// Queries
let isTerminal = (task: t): bool => Status.isTerminal(task.status)
let getStatus = (task: t): Status.t => task.status
let getId = (task: t): taskId => task.id
let getHistory = (task: t): array<Agent__Task__Message.t> => task.history
let getArtifacts = (task: t): array<Agent__Artifact.t> => task.artifacts
