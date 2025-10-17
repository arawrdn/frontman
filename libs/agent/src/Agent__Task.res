// Task aggregate root - immutable
module Status = Agent__Task__Status
module Part = Agent__Task__Message__Part

// Domain-specific ID type alias
type taskId = Agent__Task__Id.t
type history = array<Agent__Task__Message.t>
type t = {
  id: taskId,
  status: Status.t,
  history: history,
  artifacts: array<Agent__Artifact.t>,
  metadata: option<Dict.t<JSON.t>>,
}
let systemMessage = "You are an AI coding assistant helping with a Next.js project.
  The project uses TypeScript, React, and Tailwind CSS.
  \nIMPORTANT Tool Usage Guidelines:
  \n- All file paths must be RELATIVE to the project root (e.g., 'src/components/Button.tsx', not '/full/path/...')
  \n- Use list_files with directory=\".\" to see the root directory structure first
  \n- If a directory doesn't exist, try listing the parent directory to understand the structure
  \n- Read files before modifying them to understand the current code
  \n- After 2-3 failed tool calls, stop and ask the user for clarification
  \nWhen making changes, ensure they are compatible with the Next.js framework and follow React best practices."

// Constructors
let make = (~history: history=[], ~metadata=None): t => {
  let taskId = Agent__Id.make()

  let history = Array.concat(
    [Agent__Task__Message.make(~role=System, ~parts=[Part.text(~text=systemMessage)])],
    history,
  )

  {
    id: taskId,
    status: Status.initial(),
    history,
    artifacts: [],
    metadata,
  }
}

// State transitions - return new Task
let transition = (task: t, event: Status.event): result<t, string> => {
  Status.transition(task.status, event)->Result.map(newStatus => {...task, status: newStatus})
}

// Mutations - return new Task
let addMessage = (task: t, message: Agent__Task__Message.t): result<t, string> => {
  let updated_task = {...task, history: Array.concat(task.history, [message])}
  switch updated_task.status {
  | InputRequired(_) => transition(updated_task, Agent__Task__Status.Resume(Some(message)))
  | _ => Ok(updated_task)
  }
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
