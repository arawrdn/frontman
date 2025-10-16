// Event schemas for Agent communication

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
}

// // Context response (plugin responds to agent's request)
// module ContextResponseConfig = {
//   type t = {
//     requestId: string,
//     contextType: string,
//     data: JSON.t,
//   }
// }

// // ============ Agent -> Plugin Events ============

// // Status update
// module StatusUpdateConfig = {
//   type t = {
//     requestId: string,
//     message: string,
//   }

//   let name = "status"
// }

// // Context request (agent needs more info)
// module ContextRequestConfig = {
//   type t = {
//     requestId: string,
//     contextType: string,
//     params: JSON.t,
//   }

//   let name = "context_request"

//   let schema = S.object(s => {
//     requestId: s.field("requestId", S.string),
//     contextType: s.field("contextType", S.string),
//     params: s.field("params", S.json),
//   })
// }

// // Final response
// module AgentResponseConfig = {
//   type t = {
//     requestId: string,
//     message: string,
//     filesChanged: array<string>,
//   }
// }

// // Error
// module AgentErrorConfig = {
//   type t = {
//     requestId: string,
//     error: string,
//   }

//   let name = "error"

//   let schema = S.object(s => {
//     requestId: s.field("requestId", S.string),
//     error: s.field("error", S.string),
//   })
// }
// module AgentError = EventBus.Event.Make(AgentErrorConfig)

// // ============ Event Type Unions ============

// // Events the agent receives (from plugin)
// type inboundEvent =
//   | UserRequest(UserRequest.t)
//   | ContextResponse(ContextResponse.t)

// let inboundEventName = event =>
//   switch event {
//   | UserRequest(_) => UserRequest.name
//   | ContextResponse(_) => ContextResponse.name
//   }

// let inboundToJson = event =>
//   switch event {
//   | UserRequest(e) => UserRequest.toJson(e)
//   | ContextResponse(e) => ContextResponse.toJson(e)
//   }

// // Events the agent sends (to plugin)
// type outboundEvent =
//   | StatusUpdate(StatusUpdate.t)
//   | ContextRequest(ContextRequest.t)
//   | AgentResponse(AgentResponse.t)
//   | AgentError(AgentError.t)

// let outboundEventName = event =>
//   switch event {
//   | StatusUpdate(_) => StatusUpdate.name
//   | ContextRequest(_) => ContextRequest.name
//   | AgentResponse(_) => AgentResponse.name
//   | AgentError(_) => AgentError.name
//   }

// let outboundToJson = event =>
//   switch event {
//   | StatusUpdate(e) => StatusUpdate.toJson(e)
//   | ContextRequest(e) => ContextRequest.toJson(e)
//   | AgentResponse(e) => AgentResponse.toJson(e)
//   | AgentError(e) => AgentError.toJson(e)
//   }

// let outboundFromJson = (name, json) => {
//   if name == StatusUpdate.name {
//     StatusUpdate.fromJson(json)->Option.map(e => StatusUpdate(e))
//   } else if name == ContextRequest.name {
//     ContextRequest.fromJson(json)->Option.map(e => ContextRequest(e))
//   } else if name == AgentResponse.name {
//     AgentResponse.fromJson(json)->Option.map(e => AgentResponse(e))
//   } else if name == AgentError.name {
//     AgentError.fromJson(json)->Option.map(e => AgentError(e))
//   } else {
//     None
//   }
// }
