// Event schemas for Agent <-> Plugin communication

// Enable Sury JSON schema support
S.enableJson()

// ============ Plugin -> Agent Events ============

// User request with bundled context
module UserRequestConfig = {
  type selectedElement = {
    component: string,
    filePath: string,
    lineNumber: int,
    props: JSON.t,
    styles: JSON.t,
  }

  type context = {
    projectRoot: string,
    componentSource: option<string>,
    componentTree: option<JSON.t>,
    types: option<JSON.t>,
    fileStructure: option<JSON.t>,
    buildErrors: option<array<string>>,
  }

  type t = {
    requestId: string,
    selectedElement: option<selectedElement>,
    userMessage: string,
    context: context,
  }

  let name = "user_request"

  let selectedElementSchema = S.object(s => {
    component: s.field("component", S.string),
    filePath: s.field("filePath", S.string),
    lineNumber: s.field("lineNumber", S.int),
    props: s.field("props", S.json),
    styles: s.field("styles", S.json),
  })

  let contextSchema = S.object(s => {
    projectRoot: s.field("projectRoot", S.string),
    componentSource: s.field("componentSource", S.option(S.string)),
    componentTree: s.field("componentTree", S.option(S.json)),
    types: s.field("types", S.option(S.json)),
    fileStructure: s.field("fileStructure", S.option(S.json)),
    buildErrors: s.field("buildErrors", S.option(S.array(S.string))),
  })

  let schema = S.object(s => {
    requestId: s.field("requestId", S.string),
    selectedElement: s.field("selectedElement", S.option(selectedElementSchema)),
    userMessage: s.field("userMessage", S.string),
    context: s.field("context", contextSchema),
  })
}
module EventBus = AskTheLlmEventBus.EventBus
module UserRequest = EventBus.Event.Make(UserRequestConfig)

// Context response (plugin responds to agent's request)
module ContextResponseConfig = {
  type t = {
    requestId: string,
    contextType: string,
    data: JSON.t,
  }

  let name = "context_response"

  let schema = S.object(s => {
    requestId: s.field("requestId", S.string),
    contextType: s.field("contextType", S.string),
    data: s.field("data", S.json),
  })
}
module ContextResponse = EventBus.Event.Make(ContextResponseConfig)

// ============ Agent -> Plugin Events ============

// Status update
module StatusUpdateConfig = {
  type t = {
    requestId: string,
    message: string,
  }

  let name = "status"

  let schema = S.object(s => {
    requestId: s.field("requestId", S.string),
    message: s.field("message", S.string),
  })
}
module StatusUpdate = EventBus.Event.Make(StatusUpdateConfig)

// Context request (agent needs more info)
module ContextRequestConfig = {
  type t = {
    requestId: string,
    contextType: string,
    params: JSON.t,
  }

  let name = "context_request"

  let schema = S.object(s => {
    requestId: s.field("requestId", S.string),
    contextType: s.field("contextType", S.string),
    params: s.field("params", S.json),
  })
}
module ContextRequest = EventBus.Event.Make(ContextRequestConfig)

// Final response
module AgentResponseConfig = {
  type t = {
    requestId: string,
    message: string,
    filesChanged: array<string>,
  }

  let name = "response"

  let schema = S.object(s => {
    requestId: s.field("requestId", S.string),
    message: s.field("message", S.string),
    filesChanged: s.field("filesChanged", S.array(S.string)),
  })
}
module AgentResponse = EventBus.Event.Make(AgentResponseConfig)

// Error
module AgentErrorConfig = {
  type t = {
    requestId: string,
    error: string,
  }

  let name = "error"

  let schema = S.object(s => {
    requestId: s.field("requestId", S.string),
    error: s.field("error", S.string),
  })
}
module AgentError = EventBus.Event.Make(AgentErrorConfig)

// ============ Event Type Unions ============

// Events the agent receives (from plugin)
type inboundEvent =
  | UserRequest(UserRequest.t)
  | ContextResponse(ContextResponse.t)

let inboundEventName = event =>
  switch event {
  | UserRequest(_) => UserRequest.name
  | ContextResponse(_) => ContextResponse.name
  }

let inboundToJson = event =>
  switch event {
  | UserRequest(e) => UserRequest.toJson(e)
  | ContextResponse(e) => ContextResponse.toJson(e)
  }

let inboundFromJson = (name, json) => {
  if name == UserRequest.name {
    UserRequest.fromJson(json)->Option.map(e => UserRequest(e))
  } else if name == ContextResponse.name {
    ContextResponse.fromJson(json)->Option.map(e => ContextResponse(e))
  } else {
    None
  }
}

// Events the agent sends (to plugin)
type outboundEvent =
  | StatusUpdate(StatusUpdate.t)
  | ContextRequest(ContextRequest.t)
  | AgentResponse(AgentResponse.t)
  | AgentError(AgentError.t)

let outboundEventName = event =>
  switch event {
  | StatusUpdate(_) => StatusUpdate.name
  | ContextRequest(_) => ContextRequest.name
  | AgentResponse(_) => AgentResponse.name
  | AgentError(_) => AgentError.name
  }

let outboundToJson = event =>
  switch event {
  | StatusUpdate(e) => StatusUpdate.toJson(e)
  | ContextRequest(e) => ContextRequest.toJson(e)
  | AgentResponse(e) => AgentResponse.toJson(e)
  | AgentError(e) => AgentError.toJson(e)
  }

let outboundFromJson = (name, json) => {
  if name == StatusUpdate.name {
    StatusUpdate.fromJson(json)->Option.map(e => StatusUpdate(e))
  } else if name == ContextRequest.name {
    ContextRequest.fromJson(json)->Option.map(e => ContextRequest(e))
  } else if name == AgentResponse.name {
    AgentResponse.fromJson(json)->Option.map(e => AgentResponse(e))
  } else if name == AgentError.name {
    AgentError.fromJson(json)->Option.map(e => AgentError(e))
  } else {
    None
  }
}
