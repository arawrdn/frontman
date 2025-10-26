// Task aggregate root - immutable
//
module Part = Agent__Task__Message__Part

// Status types
module Status = {
  type t =
    | Submitted
    | Working({message: option<Agent__Task__Message.t>})
    | InputRequired({message: Agent__Task__Message.t})
    | Completed({message: option<Agent__Task__Message.t>})
    | Failed({message: Agent__Task__Message.t})
    | Rejected({message: Agent__Task__Message.t})
    | Canceled({message: option<Agent__Task__Message.t>})

  let isTerminal = (status: t): bool => {
    switch status {
    | Completed(_) | Failed(_) | Rejected(_) | Canceled(_) => true
    | Submitted | Working(_) | InputRequired(_) => false
    }
  }

  let toString = (status: t): string => {
    switch status {
    | Submitted => "Submitted"
    | Working(_) => "Working"
    | InputRequired(_) => "InputRequired"
    | Completed(_) => "Completed"
    | Failed(_) => "Failed"
    | Rejected(_) => "Rejected"
    | Canceled(_) => "Canceled"
    }
  }
}

// Domain-specific ID type alias
@schema
type taskId = Agent__Task__Id.t
type history = array<Agent__Task__Message.t>
type t = {
  id: taskId,
  status: Status.t,
  history: history,
  artifacts: array<Agent__Artifact.t>,
  metadata: option<Dict.t<JSON.t>>,
}

type id = Agent__Task__Id.t
type cmd = Agent__Task__Commands.t
type evt = Agent__Task__Events.t

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
  let systemMsg = Agent__Task__Message.System({
    id: Agent__Id.make(),
    taskId: Some(taskId),
    content: systemMessage,
  })
  let history = Array.concat([systemMsg], history)
  {
    id: taskId,
    status: Submitted,
    history,
    artifacts: [],
    metadata,
  }
}

// Decide: validate command against current state and produce events
// PURE FUNCTION
let decide = (state: option<t>, command: cmd): result<list<evt>, string> => {
  switch (state, command) {
  // === Creation ===
  | (None, Create({initialMessage})) => {
      let id = Agent__Id.make()
      Ok(list{Created({id, initialMessage})})
    }
  | (Some(_), Create(_)) => Error("Task already exists - cannot create again")

  // === Status Transitions ===
  | (Some({status: Submitted, _}), StartProcessing({message})) =>
    Ok(list{ProcessingStarted({message: message})})

  | (Some({status: Working(_), _}), Complete({message})) => Ok(list{Completed({message: message})})

  | (Some({status: Working(_), _}), RequestInput({question})) =>
    Ok(list{InputRequested({question: question})})

  | (Some({status: InputRequired(_), _}), Resume({message})) =>
    Ok(list{Resumed({message: message})})

  | (Some({status: Submitted, _}), Reject({reason})) => Ok(list{Rejected({reason: reason})})

  | (Some({status, _}), Fail({error})) =>
    if Status.isTerminal(status) {
      Error("Cannot fail - task already in terminal state")
    } else {
      Ok(list{Failed({error: error})})
    }

  | (Some({status, _}), Cancel({reason})) =>
    if Status.isTerminal(status) {
      Error("Cannot cancel - task already in terminal state")
    } else {
      Ok(list{Canceled({reason: reason})})
    }

  // === Message Handling ===
  | (Some({status, _}), AddMessage({message})) =>
    // Business rule: if task is InputRequired, also resume it
    switch status {
    | InputRequired(_) =>
      // Emit BOTH events: message added AND status changed
      Ok(list{MessageAdded({message: message}), Resumed({message: Some(message)})})
    | _ => Ok(list{MessageAdded({message: message})})
    }

  | (None, AddMessage(_)) => Error("Cannot add message to non-existent task")

  // === Artifact Handling ===
  | (Some(_), AddArtifact({artifact})) => Ok(list{ArtifactAdded({artifact: artifact})})

  | (None, AddArtifact(_)) => Error("Cannot add artifact to non-existent task")

  // === Invalid Transitions ===
  | (Some({status: Completed(_), _}), _) => Error("Cannot modify completed task")
  | (Some({status: Failed(_), _}), _) => Error("Cannot modify failed task")
  | (Some({status: Canceled(_), _}), _) => Error("Cannot modify canceled task")
  | (Some({status: Rejected(_), _}), _) => Error("Cannot modify rejected task")

  | (Some({status, _}), _) =>
    Error(`Invalid command for current status: ${Status.toString(status)}`)

  | (None, _) => Error("Cannot execute command on non-existent task")
  }
}

// Evolve: apply event to state
// PURE FUNCTION
let evolve = (state: option<t>, event: evt): option<t> => {
  switch (state, event) {
  // === Creation ===
  | (None, Created({id, initialMessage})) => {
      let systemMsg = Agent__Task__Message.System({
        id: Agent__Id.make(),
        taskId: Some(id),
        content: systemMessage,
      })

      Some({
        id,
        status: Status.Submitted,
        history: [systemMsg, initialMessage],
        artifacts: [],
        metadata: None,
      })
    }

  // === Status Changes ===
  | (Some(task), ProcessingStarted({message})) =>
    Some({...task, status: Working({message: message})})

  | (Some(task), Completed({message})) => Some({...task, status: Completed({message: message})})

  | (Some(task), Failed({error})) => Some({...task, status: Failed({message: error})})

  | (Some(task), Canceled({reason})) => Some({...task, status: Canceled({message: reason})})

  | (Some(task), InputRequested({question})) =>
    Some({...task, status: InputRequired({message: question})})

  | (Some(task), Resumed({message})) => Some({...task, status: Working({message: message})})

  | (Some(task), Rejected({reason})) => Some({...task, status: Rejected({message: reason})})

  // === Message Handling ===
  | (Some(task), MessageAdded({message, _})) =>
    Some({...task, history: Array.concat(task.history, [message])})

  // === Artifact Handling ===
  | (Some(task), ArtifactAdded({artifact, _})) =>
    Some({...task, artifacts: Array.concat(task.artifacts, [artifact])})

  // === Invalid ===
  | (None, _) => None
  | (Some(_), Created(_)) => %todo("implement this")
  }
}

// Queries
let isTerminal = (task: t): bool => Status.isTerminal(task.status)
let getStatus = (task: t): Status.t => task.status
let getId = (task: t): taskId => task.id
let getHistory = (task: t): array<Agent__Task__Message.t> => task.history
let getArtifacts = (task: t): array<Agent__Artifact.t> => task.artifacts
