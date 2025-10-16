type submitted = {timestamp: Agent__Timestamp.t}

type working = {
  timestamp: Agent__Timestamp.t,
  message: option<Agent__Task__Message.t>,
}

type inputRequired = {
  timestamp: Agent__Timestamp.t,
  message: Agent__Task__Message.t, // Required - must have question
}

type completed = {
  timestamp: Agent__Timestamp.t,
  message: option<Agent__Task__Message.t>,
}

type failed = {
  timestamp: Agent__Timestamp.t,
  message: Agent__Task__Message.t, // Required - must have error
}

type rejected = {
  timestamp: Agent__Timestamp.t,
  message: Agent__Task__Message.t, // Required - must have reason
}

type canceled = {
  timestamp: Agent__Timestamp.t,
  message: option<Agent__Task__Message.t>, // Optional cancellation reason
}

// Status union
type t =
  | Submitted(submitted)
  | Working(working)
  | InputRequired(inputRequired)
  | Completed(completed)
  | Failed(failed)
  | Rejected(rejected)
  | Canceled(canceled)

// Status transition events
type event =
  | StartProcessing(option<Agent__Task__Message.t>)
  | RequestInput(Agent__Task__Message.t)
  | Resume(option<Agent__Task__Message.t>)
  | Complete(option<Agent__Task__Message.t>)
  | Fail(Agent__Task__Message.t)
  | Reject(Agent__Task__Message.t)
  | Cancel(option<Agent__Task__Message.t>)

// Define legal status transitions
let transition = (current: t, event: event): result<t, string> => {
  switch (current, event) {
  // From Submitted
  | (Submitted(_), StartProcessing(message)) =>
    Ok(Working({timestamp: Agent__Timestamp.make(), message}))
  | (Submitted(_), Reject(message)) => Ok(Rejected({timestamp: Agent__Timestamp.make(), message}))
  | (Submitted(_), Cancel(message)) => Ok(Canceled({timestamp: Agent__Timestamp.make(), message}))

  // From Working
  | (Working(_), Complete(message)) => Ok(Completed({timestamp: Agent__Timestamp.make(), message}))
  | (Working(_), RequestInput(message)) =>
    Ok(InputRequired({timestamp: Agent__Timestamp.make(), message}))
  | (Working(_), Fail(message)) => Ok(Failed({timestamp: Agent__Timestamp.make(), message}))
  | (Working(_), Cancel(message)) => Ok(Canceled({timestamp: Agent__Timestamp.make(), message}))

  // From InputRequired
  | (InputRequired(_), Resume(message)) => Ok(Working({timestamp: Agent__Timestamp.make(), message}))
  | (InputRequired(_), Fail(message)) => Ok(Failed({timestamp: Agent__Timestamp.make(), message}))
  | (InputRequired(_), Cancel(message)) => Ok(Canceled({timestamp: Agent__Timestamp.make(), message}))

  // Terminal statuses cannot transition
  | (Completed(_), _) => Error("Cannot transition from completed status")
  | (Failed(_), _) => Error("Cannot transition from failed status")
  | (Rejected(_), _) => Error("Cannot transition from rejected status")
  | (Canceled(_), _) => Error("Cannot transition from canceled status")

  // All other transitions are illegal
  | (_, _) => Error("Illegal status transition")
  }
}

// Check if status is terminal
let isTerminal = (status: t): bool => {
  switch status {
  | Completed(_) | Failed(_) | Rejected(_) | Canceled(_) => true
  | _ => false
  }
}

// Initial status constructor
let initial = (): t => {
  Submitted({timestamp: Agent__Timestamp.make()})
}

// Get current message from status (if any)
let getMessage = (status: t): option<Agent__Task__Message.t> => {
  switch status {
  | Submitted(_) => None
  | Working({message}) => message
  | InputRequired({message}) => Some(message)
  | Completed({message}) => message
  | Failed({message}) => Some(message)
  | Rejected({message}) => Some(message)
  | Canceled({message}) => message
  }
}

// Get timestamp from status
let getTimestamp = (status: t): Agent__Timestamp.t => {
  switch status {
  | Submitted({timestamp}) => timestamp
  | Working({timestamp}) => timestamp
  | InputRequired({timestamp}) => timestamp
  | Completed({timestamp}) => timestamp
  | Failed({timestamp}) => timestamp
  | Rejected({timestamp}) => timestamp
  | Canceled({timestamp}) => timestamp
  }
}
