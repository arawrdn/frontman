// ACP Protocol helpers
// Centralizes JSON-RPC request/response pattern and message handling

module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Client = FrontmanClient__ACP__Client
module Channel = FrontmanClient__Phoenix__Channel
module JsonRpc = FrontmanAiFrontmanProtocol.FrontmanProtocol__JsonRpc
module Constants = FrontmanClient__Transport__Constants

type messageDirection = Send | Receive

// Generic request sender - eliminates duplication across sendInitialize, createSession, sendPrompt
let sendRequest = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~method: string,
  ~params: option<JSON.t>,
  ~parseResult: JSON.t => result<'a, string>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<'a, string>> => {
  Promise.make((resolve, _) => {
    let id = state.contents.currentId + 1
    let request = JsonRpc.Request.make(~id, ~method, ~params)

    let pending: Client.pendingRequest = {
      resolve: json => {
        switch parseResult(json) {
        | Ok(result) => resolve(Ok(result))
        | Error(e) => resolve(Error(e))
        }
      },
      reject: e => resolve(Error(e)),
    }

    state := state.contents->Client.reduce(Client.RequestSent(id, pending))

    let payload = request->JsonRpc.Request.toJson
    onMessage->Option.forEach(cb => cb(Send, payload))
    channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
  })
}

// Typed wrappers for specific ACP methods

let sendInitialize = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~clientConfig: Client.config,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.initializeResult, string>> => {
  let params = Client.buildInitializeParams(clientConfig)
  sendRequest(
    ~channel,
    ~state,
    ~method="initialize",
    ~params=Some(params),
    ~parseResult=Client.parseInitializeResult,
    ~onMessage,
  )
}

let sendSessionNew = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~sessionId: string,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.sessionNewResult, string>> => {
  let params = Dict.make()
  params->Dict.set("sessionId", JSON.Encode.string(sessionId))
  sendRequest(
    ~channel,
    ~state,
    ~method="session/new",
    ~params=Some(JSON.Encode.object(params)),
    ~parseResult=Client.parseSessionNewResult,
    ~onMessage,
  )
}

let sendPrompt = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~sessionId: string,
  ~prompt: array<JSON.t>,
  ~metadata: option<JSON.t>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): promise<result<Types.promptResult, string>> => {
  let entries = [
    ("sessionId", JSON.Encode.string(sessionId)),
    ("prompt", JSON.Encode.array(prompt)),
  ]
  // Add metadata if provided
  let entries = switch metadata {
  | Some(meta) => Array.concat(entries, [("metadata", meta)])
  | None => entries
  }
  let promptParams = JSON.Encode.object(Dict.fromArray(entries))
  sendRequest(
    ~channel,
    ~state,
    ~method="session/prompt",
    ~params=Some(promptParams),
    ~parseResult=Client.parsePromptResult,
    ~onMessage,
  )
}

// ACP spec: session/cancel is a NOTIFICATION (no id, no response expected).
// The pending session/prompt request will be resolved by the agent with stopReason: "cancelled".
let sendCancel = (
  ~channel: Channel.t,
  ~sessionId: string,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
): unit => {
  let cancelParams = JSON.Encode.object(
    Dict.fromArray([("sessionId", JSON.Encode.string(sessionId))]),
  )
  let notification = JsonRpc.Notification.make(
    ~method="session/cancel",
    ~params=Some(cancelParams),
  )
  let payload = notification->JsonRpc.Notification.toJson
  onMessage->Option.forEach(cb => cb(Send, payload))
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

// Extract method from JSON-RPC message (notifications have method, responses have id)
let getMethod = (payload: JSON.t): option<string> => {
  payload
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get("method"))
  ->Option.flatMap(JSON.Decode.string)
}

// Extract id from JSON-RPC message (requests have id + method, responses have id only)
// Returns the raw JSON value since server elicitation requests use string IDs (tool_call_id)
// while client-originated requests use int IDs.
let getId = (payload: JSON.t): option<JSON.t> => {
  payload
  ->JSON.Decode.object
  ->Option.flatMap(obj => obj->Dict.get("id"))
}

// Send an elicitation response (JSON-RPC response) on the ACP channel.
// The id is the raw JSON value from the incoming request (string tool_call_id).
let sendElicitationResponse = (
  ~channel: Channel.t,
  ~id: JSON.t,
  ~action: string,
  ~content: option<JSON.t>,
): unit => {
  let resultDict = Dict.make()
  resultDict->Dict.set("action", JSON.Encode.string(action))
  content->Option.forEach(c => resultDict->Dict.set("content", c))
  let result = JSON.Encode.object(resultDict)

  let responseDict = Dict.fromArray([
    ("jsonrpc", JSON.Encode.string("2.0")),
    ("id", id),
    ("result", result),
  ])
  let payload = JSON.Encode.object(responseDict)
  channel->Channel.push(~event=Constants.acpMessageEvent, ~payload)->ignore
}

// Message handler with proper error reporting (no silent swallowing)
// onUpdate receives (sessionId, update) per ACP session/update notification params
// onRequest receives (id, method, payload) for incoming JSON-RPC requests (e.g. session/elicitation)
let handleIncomingMessage = (
  ~state: ref<Client.state>,
  ~onUpdate: option<(string, Types.sessionUpdate) => unit>,
  ~onRequest: option<(JSON.t, string, JSON.t) => unit>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
  ~onParseError: option<string => unit>,
  payload: JSON.t,
): unit => {
  onMessage->Option.forEach(cb => cb(Receive, payload))

  // Dispatch based on message type
  switch getMethod(payload) {
  | Some("session/update") =>
    // Session update notification - parse and dispatch with sessionId
    switch Client.parseSessionUpdateNotification(payload) {
    | Ok(notification) =>
      onUpdate->Option.forEach(cb => cb(notification.params.sessionId, notification.params.update))
    | Error(parseError) => onParseError->Option.forEach(cb => cb(parseError))
    }
  | Some(method) =>
    // Has method field — check if it also has an id (request vs notification)
    switch getId(payload) {
    | Some(id) =>
      // Has both method and id — incoming request (e.g. session/elicitation)
      onRequest->Option.forEach(cb => cb(id, method, payload))
    | None =>
      // Has method but no id — notification (e.g. mcp_initialization_complete)
      ()
    }
  | None =>
    // No method field - must be a response
    state := Client.handleResponse(state.contents, payload)
  }
}

// Setup channel listener for ACP messages
let attachMessageHandler = (
  ~channel: Channel.t,
  ~state: ref<Client.state>,
  ~onUpdate: option<(string, Types.sessionUpdate) => unit>,
  ~onRequest: option<(JSON.t, string, JSON.t) => unit>,
  ~onMessage: option<(messageDirection, JSON.t) => unit>,
  ~onParseError: option<string => unit>,
): unit => {
  channel->Channel.on(~event=Constants.acpMessageEvent, ~callback=payload =>
    handleIncomingMessage(~state, ~onUpdate, ~onRequest, ~onMessage, ~onParseError, payload)
  )
}
