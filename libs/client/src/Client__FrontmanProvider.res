// FrontmanProvider - React context provider for FrontmanClient ACP connection
// Uses ConnectionReducer for centralized state management

module Log = FrontmanLogs.Logs.Make({
  let component = #FrontmanProvider
})

module ACP = FrontmanAiFrontmanClient.FrontmanClient__ACP
module Types = FrontmanAiFrontmanProtocol.FrontmanProtocol__ACP
module Channel = FrontmanAiFrontmanClient.FrontmanClient__Phoenix__Channel
module Relay = FrontmanAiFrontmanClient.FrontmanClient__Relay
module MCPServer = FrontmanAiFrontmanClient.FrontmanClient__MCP__Server
module Reducer = Client__ConnectionReducer
module RuntimeConfig = Client__RuntimeConfig

// Create the text delta buffer instance and register it as active.
// The onFlush callback breaks the circular dep: TextDeltaBuffer doesn't import Client__State.
let textDeltaBuffer = Client__TextDeltaBuffer.make(~onFlush=(~taskId, ~text, ~timestamp) => {
  Client__State.Actions.textDeltaReceived(~taskId, ~text, ~timestamp)
})
let () = Client__TextDeltaBuffer.active := Some(textDeltaBuffer)

// Re-export status types for consumers
type connectionState = Reducer.Selectors.connectionStatus
type mcpState = Reducer.Selectors.mcpStatus

module Protocol = FrontmanAiFrontmanClient.FrontmanClient__ACP__Protocol

// Context value type
type contextValue = {
  connectionState: connectionState,
  mcpState: mcpState,
  isSendingPrompt: bool,
  session: option<ACP.session>,
  relay: option<Relay.t>,
  authRedirectUrl: option<string>,
  createSession: (~onComplete: result<string, string> => unit) => unit,
  clearSession: unit => unit,
  sendPrompt: (
    string,
    ~additionalBlocks: array<Types.contentBlock>,
    ~onComplete: result<Types.promptResult, string> => unit,
    ~metadata: option<JSON.t>,
  ) => unit,
  cancelPrompt: unit => unit,
  respondToElicitation: Client__State__Types.respondToElicitationFn,
  loadTask: (string, ~needsHistory: bool, ~metadata: option<JSON.t>, ~onComplete: result<unit, string> => unit) => unit,
  deleteSession: (string, ~onComplete: result<unit, string> => unit) => unit,
}

// Default context value
let defaultContextValue: contextValue = {
  connectionState: Disconnected,
  mcpState: MCPDisconnected,
  isSendingPrompt: false,
  session: None,
  relay: None,
  authRedirectUrl: None,
  createSession: (~onComplete as _) => (),
  clearSession: () => (),
  sendPrompt: (_, ~additionalBlocks as _, ~onComplete as _, ~metadata as _) => (),
  cancelPrompt: () => (),
  respondToElicitation: (~requestId as _, ~action as _, ~content as _) => (),
  loadTask: (_, ~needsHistory as _, ~metadata as _, ~onComplete as _) => (),
  deleteSession: (_, ~onComplete as _) => (),
}

// Create the React context
let context = React.createContext(defaultContextValue)

// Make the context provider component
module ContextProvider = {
  let make = React.Context.provider(context)
}

// Custom hook to use the Frontman context
let useFrontman = () => React.useContext(context)

// Provider component
module Provider = {
  @react.component
  let make = (
    ~endpoint: string,
    ~tokenUrl: string,
    ~loginUrl: string,
    ~clientName: string="frontman-client",
    ~clientVersion: string="1.0.0",
    ~children: React.element,
  ) => {
    // Log message handlers
    let logACPMessage = React.useCallback0((direction: ACP.messageDirection, payload: JSON.t) => {
      let arrow = direction == Send ? `→` : `←`
      Log.debug(~ctx={"payload": payload}, `ACP ${arrow}`)
    })

    let logMCPMessage = React.useCallback0((direction, payload) => {
      let arrow = direction == FrontmanAiFrontmanClient.FrontmanClient__MCP.Send ? `→` : `←`
      Log.debug(~ctx={"payload": payload}, `MCP ${arrow}`)
    })

    // Use StateReducer - effects are executed in useEffect, not during dispatch
    let (state, dispatch) = StateReducer.useReducer(module(Reducer), Reducer.initialState)

    // Single initialization effect
    React.useEffect0(() => {
      let location = WebAPI.Global.location
      let baseUrl = `${location.protocol}//${location.host}`

      // Read runtime config from window.__frontmanRuntime (injected by framework middleware)
      let runtimeConfig = RuntimeConfig.read()
      let metadata = RuntimeConfig.toMetadata(runtimeConfig)

      let relay = Relay.make(~baseUrl)
      let toolRegistry = Client__ToolRegistry.coreBrowserTools()
      let mcpServer = MCPServer.make(~relay, ~serverName=clientName, ~serverVersion=clientVersion)
      let mcpServer = Client__ToolRegistry.registerAll(toolRegistry, mcpServer)

      // Wire up image ref resolver so write_file can save user-attached images.
      MCPServer.setImageRefResolver(mcpServer, (uri, ~taskId) => {
        let state = StateStore.getState(Client__State__Store.store)
        Client__State.Selectors.resolveImageRef(state, ~taskId, ~uri)
        ->Option.map(({base64, mediaType}) => {MCPServer.base64, mediaType})
      })

      let config: Reducer.initConfig = {
        endpoint,
        tokenUrl,
        loginUrl,
        clientName,
        clientVersion,
        baseUrl,
        onACPMessage: logACPMessage,
        metadata,
        onTitleUpdated: Some((taskId, title) => {
          Client__State.Actions.updateTaskTitle(~taskId, ~title)
        }),
      }

      dispatch(Initialize({config, relay, mcpServer}))

      Some(() => {
        textDeltaBuffer.reset()
        dispatch(Cleanup)
      })
    })

    let handleSessionUpdate = React.useCallback0((sessionId: string, update: Types.sessionUpdate) => {
      let taskId = sessionId
      switch update {
      | AgentMessageChunk({content, timestamp}) =>
        // Per ACP spec: first agent_message_chunk implicitly signals message start.
        // Message end is signaled by session/prompt response with stopReason.
        // Buffer text deltas and flush once per animation frame to avoid
        // dozens of full state rebuilds per second during fast streaming.
        content->Option.flatMap(c => c.text)->Option.forEach(text => {
          textDeltaBuffer.add(~taskId, ~text, ~timestamp)
        })
      | UserMessageChunk({content, timestamp}) =>
        // Flush buffered agent text BEFORE dispatching the user message so
        // the preceding assistant response is committed to state first.
        // Without this, during history replay the rAF-buffered agent text
        // would be lost because UserMessageReceived calls completeStreamingMessage
        // before the buffer has flushed.
        textDeltaBuffer.flush()
        content.text->Option.forEach(text => {
          let id = `user-hydrated-${WebAPI.Global.crypto->WebAPI.Crypto.randomUUID}`
          Client__State.Actions.userMessageReceived(~taskId, ~id, ~text, ~timestamp)
        })
      | ToolCall({toolCallId, title, parentAgentId, spawningToolName, timestamp}) =>
        // Flush buffered agent text before the tool call for the same reason:
        // ToolCallReceived calls completeStreamingMessage.
        textDeltaBuffer.flush()
        // Use server timestamp when available (history replay) so tool calls
        // sort correctly relative to other messages. Without this, Date.now()
        // produces a much later timestamp causing tool calls to float to the
        // end of the message list after LoadComplete sorting.
        let createdAt = switch timestamp {
        | Some(ts) => Date.fromString(ts)->Date.getTime
        | None => Date.now()
        }
        Client__State.Actions.toolCallReceived(~taskId, ~toolCall={
          id: toolCallId,
          toolName: title->Option.getOr("unknown_tool"),
          inputBuffer: "",
          input: None,
          result: None,
          errorText: None,
          state: Client__State__Types.Message.InputStreaming,
          createdAt,
          parentAgentId,
          spawningToolName,
        })
      | ToolCallUpdate({toolCallId, status, content}) =>
        let text = content->Option.flatMap(c => c->Array.get(0))->Option.flatMap(i => i.content)->Option.flatMap(c => c.text)
        switch status {
        | Some(Types.Pending) =>
          text->Option.flatMap(t => try { Some(JSON.parseOrThrow(t)) } catch { | _ => None })->Option.forEach(input => {
            Client__State.Actions.toolInputReceived(~taskId, ~id=toolCallId, ~input)
          })
        | Some(Completed) =>
          let result = text->Option.mapOr(JSON.Encode.null, t =>
            try { JSON.parseOrThrow(t) } catch { | _ => JSON.Encode.string(t) }
          )
          Client__State.Actions.toolResultReceived(~taskId, ~id=toolCallId, ~result)
        | Some(Failed) =>
          Client__State.Actions.toolErrorReceived(~taskId, ~id=toolCallId, ~error=text->Option.getOr("Unknown error"))
        | Some(InProgress) => () // Normal transitional status for MCP tools
        | None => ()
        }
      | Plan({entries}) =>
        Client__State.Actions.planReceived(~taskId, ~entries)
      | AgentTurnComplete(_) =>
        // The agent finished a turn that was resumed after an elicitation response
        // (no pending session/prompt request). Flush buffered text and finalize
        // the streaming message, same as the normal onComplete path.
        textDeltaBuffer.flush()
        Client__State.Actions.turnCompleted(~taskId)
      | Error({message}) =>
        Client__State.Actions.agentErrorReceived(~taskId, ~error=message)
      | Unknown(_) => ()
      }
    })

    // Handle incoming session/elicitation requests from the server.
    // Parses the requestedSchema properties back into questionItem array and dispatches
    // ElicitationReceived to the state store.
    let handleElicitationRequest = React.useCallback0((id: JSON.t, _method: string, payload: JSON.t) => {
      // Extract params from the JSON-RPC request
      let params =
        payload
        ->JSON.Decode.object
        ->Option.flatMap(obj => obj->Dict.get("params"))
        ->Option.flatMap(JSON.Decode.object)

      switch params {
      | None => Log.error("session/elicitation: missing params")
      | Some(paramsObj) =>
        let sessionId =
          paramsObj
          ->Dict.get("sessionId")
          ->Option.flatMap(JSON.Decode.string)
          ->Option.getOr("")
        let requestId = switch id->JSON.Decode.string {
        | Some(s) => s
        | None =>
          // Fallback: use float id as string
          switch id->JSON.Decode.float {
          | Some(f) => Float.toString(f)
          | None => ""
          }
        }

        // Parse requestedSchema.properties into questionItem array
        let schema =
          paramsObj
          ->Dict.get("requestedSchema")
          ->Option.flatMap(JSON.Decode.object)

        let properties =
          schema
          ->Option.flatMap(s => s->Dict.get("properties"))
          ->Option.flatMap(JSON.Decode.object)

        let questions: array<Client__Question__Types.questionItem> = switch properties {
        | None => []
        | Some(props) =>
          // Collect q{i}_answer entries, sorted by index
          let answerKeys =
            props
            ->Dict.keysToArray
            ->Array.filter(k => k->String.endsWith("_answer"))
          answerKeys->Array.toSorted((a, b) => String.compare(a, b))
          ->Array.filterMap(key => {
            let prop = props->Dict.get(key)->Option.flatMap(JSON.Decode.object)
            switch prop {
            | None => None
            | Some(propObj) =>
              let header = propObj->Dict.get("title")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
              let question = propObj->Dict.get("description")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
              let propType = propObj->Dict.get("type")->Option.flatMap(JSON.Decode.string)->Option.getOr("string")

              // Extract options from oneOf (single select) or items.anyOf (multi select)
              let optionEntries = switch propType {
              | "array" =>
                // Multi-select: items.anyOf
                propObj
                ->Dict.get("items")
                ->Option.flatMap(JSON.Decode.object)
                ->Option.flatMap(items => items->Dict.get("anyOf"))
                ->Option.flatMap(JSON.Decode.array)
                ->Option.getOr([])
              | _ =>
                // Single-select: oneOf
                propObj
                ->Dict.get("oneOf")
                ->Option.flatMap(JSON.Decode.array)
                ->Option.getOr([])
              }

              let options: array<Client__Question__Types.questionOption> =
                optionEntries->Array.filterMap(entry => {
                  let entryObj = entry->JSON.Decode.object
                  switch entryObj {
                  | None => None
                  | Some(obj) =>
                    let label = obj->Dict.get("const")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
                    // title format is "Label - Description"
                    let titleStr = obj->Dict.get("title")->Option.flatMap(JSON.Decode.string)->Option.getOr("")
                    let description = switch titleStr->String.indexOf(" - ") {
                    | -1 => ""
                    | idx => titleStr->String.slice(~start=idx + 3, ~end=String.length(titleStr))
                    }
                    Some({Client__Question__Types.label, description})
                  }
                })

              let multiple = switch propType {
              | "array" => Some(true)
              | _ => None
              }

              Some({Client__Question__Types.question, header, options, multiple})
            }
          })
        }

        Client__State.Actions.elicitationReceived(~taskId=sessionId, ~questions, ~requestId)
      }
    })

    // Send an elicitation response via the ACP channel.
    // Called by the state reducer's NeedElicitationResponse effect.
    let currentSession = Reducer.Selectors.getSession(state)
    let respondToElicitation = React.useCallback1(
      (~requestId: string, ~action: string, ~content: option<JSON.t>) => {
        switch currentSession {
        | Some(session) =>
          Protocol.sendElicitationResponse(
            ~channel=session.channel,
            ~id=JSON.Encode.string(requestId),
            ~action,
            ~content,
          )
        | None =>
          Log.error("Cannot send elicitation response: no active session")
        }
      },
      [currentSession],
    )

    let createSession = React.useCallback1(
      (~onComplete: result<string, string> => unit) => {
        dispatch(CreateSession({onUpdate: handleSessionUpdate, onRequest: Some(handleElicitationRequest), onMcpMessage: logMCPMessage, onComplete}))
      },
      [dispatch],
    )

    let clearSession = React.useCallback1(() => dispatch(ClearSession), [dispatch])

    let sendPrompt = React.useCallback1(
      (text: string, ~additionalBlocks, ~onComplete, ~metadata) => {
        dispatch(SendPrompt({text, additionalBlocks, onComplete, metadata}))
      },
      [dispatch],
    )

    let cancelPrompt = React.useCallback1(() => {
      dispatch(CancelPrompt)
    }, [dispatch])

    let loadTask = React.useCallback1(
      (taskId: string, ~needsHistory, ~metadata, ~onComplete) => {
        dispatch(LoadTask({taskId, needsHistory, metadata, onUpdate: handleSessionUpdate, onRequest: Some(handleElicitationRequest), onMcpMessage: logMCPMessage, onComplete}))
      },
      [dispatch],
    )

    let deleteSession = React.useCallback1(
      (taskId: string, ~onComplete) => {
        dispatch(DeleteSession({taskId, onComplete}))
      },
      [dispatch],
    )

    // Extract auth redirect URL from ACP error state (encoded as "auth_required:<url>")
    let authRedirectUrl = switch state.acp {
    | Reducer.ACPError(msg) =>
      switch String.startsWith(msg, "auth_required:") {
      | true => Some(String.slice(msg, ~start=14, ~end=String.length(msg)))
      | false => None
      }
    | _ => None
    }

    let contextValue: contextValue = {
      connectionState: Reducer.Selectors.getConnectionStatus(state),
      mcpState: Reducer.Selectors.getMCPStatus(state),
      isSendingPrompt: state.isSendingPrompt,
      session: Reducer.Selectors.getSession(state),
      relay: state.relayInstance,
      authRedirectUrl,
      createSession,
      clearSession,
      sendPrompt,
      cancelPrompt,
      respondToElicitation,
      loadTask,
      deleteSession,
    }

    <ContextProvider value={contextValue}> {children} </ContextProvider>
  }
}
