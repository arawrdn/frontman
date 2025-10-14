// Plugin Bus - handles all communication with the plugin via STDIO

// All events for plugin communication
type event =
  | UserRequest(Agent__Events.UserRequest.t)
  | AgentResponse(Agent__Events.AgentResponse.t)
  | AgentError(Agent__Events.AgentError.t)
  | ContextRequest(Agent__Events.ContextRequest.t)
  | ContextResponse(Agent__Events.ContextResponse.t)
  | StatusUpdate(Agent__Events.StatusUpdate.t)

let eventName = event =>
  switch event {
  | UserRequest(_) => Agent__Events.UserRequest.name
  | AgentResponse(_) => Agent__Events.AgentResponse.name
  | AgentError(_) => Agent__Events.AgentError.name
  | ContextRequest(_) => Agent__Events.ContextRequest.name
  | ContextResponse(_) => Agent__Events.ContextResponse.name
  | StatusUpdate(_) => Agent__Events.StatusUpdate.name
  }

let toJson = event =>
  switch event {
  | UserRequest(e) => Agent__Events.UserRequest.toJson(e)
  | AgentResponse(e) => Agent__Events.AgentResponse.toJson(e)
  | AgentError(e) => Agent__Events.AgentError.toJson(e)
  | ContextRequest(e) => Agent__Events.ContextRequest.toJson(e)
  | ContextResponse(e) => Agent__Events.ContextResponse.toJson(e)
  | StatusUpdate(e) => Agent__Events.StatusUpdate.toJson(e)
  }

let fromJson = (name, json) => {
  if name == Agent__Events.UserRequest.name {
    Agent__Events.UserRequest.fromJson(json)->Option.map(e => UserRequest(e))
  } else if name == Agent__Events.ContextResponse.name {
    Agent__Events.ContextResponse.fromJson(json)->Option.map(e => ContextResponse(e))
  } else if name == Agent__Events.StatusUpdate.name {
    Agent__Events.StatusUpdate.fromJson(json)->Option.map(e => StatusUpdate(e))
  } else if name == Agent__Events.ContextRequest.name {
    Agent__Events.ContextRequest.fromJson(json)->Option.map(e => ContextRequest(e))
  } else if name == Agent__Events.AgentResponse.name {
    Agent__Events.AgentResponse.fromJson(json)->Option.map(e => AgentResponse(e))
  } else if name == Agent__Events.AgentError.name {
    Agent__Events.AgentError.fromJson(json)->Option.map(e => AgentError(e))
  } else {
    None
  }
}

module Bus = EventBus.RemoteBus.Make(
  {
    type t = event
    let eventName = eventName
    let toJson = toJson
    let fromJson = fromJson
  },
  EventBus.StdioTransport,
)

type t = Bus.t

let make = async () => {
  let bus = Bus.make()
  await Bus.connect(bus)
  bus
}
//Note(Danni): not sure if commands/hooks need to be centralized here, probably no need for it
// Listen for user requests from plugin
let onUserRequest = (bus, handler) => {
  Bus.on(bus, event =>
    switch event {
    | UserRequest(req) => handler(req)
    | _ => ()
    }
  )
}

// Listen for context responses from plugin
let onContextResponse = (bus, handler) => {
  Bus.on(bus, event =>
    switch event {
    | ContextResponse(resp) => handler(resp)
    | _ => ()
    }
  )
}

// Send status update to plugin
let sendStatus = async (bus, ~requestId, ~message) => {
  let event = StatusUpdate({
    requestId,
    message,
  })
  await Bus.emit(bus, event)
}

// Send context request to plugin
let sendContextRequest = async (bus, ~requestId, ~contextType, ~params) => {
  let event = ContextRequest({
    requestId,
    contextType,
    params,
  })
  await Bus.emit(bus, event)
}

// Send response to plugin
let sendResponse = async (bus, ~requestId, ~message, ~filesChanged) => {
  let event = AgentResponse({
    requestId,
    message,
    filesChanged,
  })
  await Bus.emit(bus, event)
}

// Send error to plugin
let sendError = async (bus, ~requestId, ~error) => {
  let event = AgentError({
    requestId,
    error,
  })
  await Bus.emit(bus, event)
}
