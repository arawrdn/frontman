// Events represent facts - what actually happened
// These are the ONLY way state changes

type t =
  // Lifecycle events
  | Created({id: Agent__Task__Id.t, initialMessage: Agent__Task__Message.t})
  | ProcessingStarted({message: option<Agent__Task__Message.t>})
  | Completed({message: option<Agent__Task__Message.t>})
  | Failed({error: Agent__Task__Message.t})
  | Canceled({reason: option<Agent__Task__Message.t>})
  // Message events
  | MessageAdded({message: Agent__Task__Message.t})
  // Status events
  | InputRequested({question: Agent__Task__Message.t})
  | Resumed({message: option<Agent__Task__Message.t>})
  | Rejected({reason: Agent__Task__Message.t})
  // Artifact events
  | ArtifactAdded({artifact: Agent__Artifact.t})
