// Message - opaque type with safe construction

module Part = Agent__Task__Message__Part
type role = User | Agent | System
type t = {
  role: role,
  parts: array<Part.t>,
  messageId: Agent__Id.t,
  taskId: option<Agent__Task__Id.t>,
  metadata: option<Dict.t<JSON.t>>,
}

let make = (
  ~role: role,
  ~parts: array<Part.t>,
  ~taskId: option<Agent__Task__Id.t>=None,
  ~metadata: option<Dict.t<JSON.t>>=None,
): t => {
  {
    role,
    parts,
    messageId: Agent__Id.make(),
    taskId,
    metadata,
  }
}

// Accessor for getting parts (needed for LLM conversion)
let getParts = (msg: t): array<Part.t> => msg.parts
let getRole = (msg: t): role => msg.role
let getMetadata = (msg: t): option<Dict.t<JSON.t>> => msg.metadata
let getTaskId = (msg: t): option<Agent__Task__Id.t> => msg.taskId
