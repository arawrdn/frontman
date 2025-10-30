// Re-export types
type state = Client__State__StateReducer.state
type action = Client__State__StateReducer.action

// Hook for selecting state
let useSelector = selection =>
  AskTheLlmReactStatestore.StateStore.useSelector(Client__State__Store.store, selection)

// Re-export selectors
module Selectors = Client__State__StateReducer.Selectors

// Re-export content part modules for convenience
module UserContentPart = Client__State__StateReducer.UserContentPart
module AssistantContentPart = Client__State__StateReducer.AssistantContentPart

// Action creators
module Actions = {
  // User message action
  let addUserMessage = (~content) => {
    let id = `user-${Date.now()->Float.toString}`
    Client__State__Store.dispatch(AddUserMessage({id, content}))
  }

  // Convenience for text-only user messages
  let addUserTextMessage = (~id, ~text) =>
    Client__State__Store.dispatch(
      AddUserMessage({
        id,
        content: [UserContentPart.Text({text: text})],
      }),
    )

  // Streaming actions (typically called from SSE handlers)
  let streamingStarted = (~id) => Client__State__Store.dispatch(StreamingStarted({id: id}))

  let textDeltaReceived = (~id, ~text) =>
    Client__State__Store.dispatch(TextDeltaReceived({id, text}))

  let toolCallReceived = (~id, ~toolCall) =>
    Client__State__Store.dispatch(ToolCallReceived({id, toolCall}))

  let messageCompleted = (~id) => Client__State__Store.dispatch(MessageCompleted({id: id}))

  // Preview document actions
  let setPreviewUrl = (~url) => Client__State__Store.dispatch(SetPreviewUrl({url: url}))

  let setPreviewDocument = (~document) =>
    Client__State__Store.dispatch(SetPreviewDocument({document: document}))

  // WebPreview selection actions
  let toggleWebPreviewSelection = () => Client__State__Store.dispatch(ToggleWebPreviewSelection)

  let setSelectedElement = (~selectedElement) =>
    Client__State__Store.dispatch(SetSelectedElement({selectedElement: selectedElement}))
}
