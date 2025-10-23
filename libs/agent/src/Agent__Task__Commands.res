// Commands represent intent - what we want to do
// These are requests that may succeed or fail based on current state

type t =
  // Lifecycle commands
  | Create({initialMessage: Agent__Task__Message.t})
  | StartProcessing({message: option<Agent__Task__Message.t>})
  | Complete({message: option<Agent__Task__Message.t>})
  | Fail({error: Agent__Task__Message.t})
  | Cancel({reason: option<Agent__Task__Message.t>})
  // Message commands
  | AddMessage({message: Agent__Task__Message.t})
  // Artifact commands
  | AddArtifact({artifact: Agent__Artifact.t})
  // Status commands
  | RequestInput({question: Agent__Task__Message.t})
  | Resume({message: option<Agent__Task__Message.t>})
  | Reject({reason: Agent__Task__Message.t})
