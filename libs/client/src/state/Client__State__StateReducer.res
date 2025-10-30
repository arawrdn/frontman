module Agent = AskTheLlmAgent.Agent
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
let name = "Client::StateReducer"

// ============================================================================
// Message Content Types
// ============================================================================

// Reuse content part types from agent bindings
module UserContentPart = Vercel.UserPart
module AssistantContentPart = Vercel.AssistantPart

// Tool call tracking (for streaming accumulation)
type toolCall = {
  toolCallId: string,
  toolName: string,
  input: JSON.t,
}

// ============================================================================
// Message Types
// ============================================================================

// Assistant messages can be streaming or completed
type assistantMessage =
  | Streaming({id: string, textBuffer: string, toolCalls: array<toolCall>, createdAt: float})
  | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

// Top-level message variant
type message =
  | User({id: string, content: array<UserContentPart.t>, createdAt: float})
  | Assistant(assistantMessage)

// Preview document with URL and optional loaded document
type previewDocument = {
  url: string,
  document: option<WebAPI.DOMAPI.document>,
}

// Selected element data with selector, screenshot, and source location
type selectedElementData = {
  element: WebAPI.DOMAPI.element,
  selector: option<string>,
  screenshot: option<string>,
  sourceLocation: option<Client__Types.sourceLocation>,
}

type state = {
  messages: array<message>,
  previewDocument: previewDocument,
  webPreviewIsSelecting: bool,
  selectedElement: option<selectedElementData>,
}

type action =
  // User actions
  | AddUserMessage({id: string, content: array<UserContentPart.t>})
  // Streaming actions (from SSE events)
  | StreamingStarted({id: string})
  | TextDeltaReceived({id: string, text: string})
  | ToolCallReceived({id: string, toolCall: toolCall})
  // Completion action
  | MessageCompleted({id: string})
  // Preview document actions
  | SetPreviewUrl({url: string})
  | SetPreviewDocument({document: option<WebAPI.DOMAPI.document>})
  // WebPreview selection actions
  | ToggleWebPreviewSelection
  | SetSelectedElement({selectedElement: option<selectedElementData>})

// Effects for side effects
type effect = SendMessageToAPI({message: string})

let getInitialUrl = () => {
  // Check if window is available (browser environment)
  switch %external(window) {
  | Some(win) => {
      let currentUrl =
        win->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
      `${currentUrl.protocol}//${currentUrl.host}`
    }
  | None => "http://localhost:3000" // Default for test environment
  }
}

let defaultState: state = {
  messages: [],
  previewDocument: {url: getInitialUrl(), document: None},
  webPreviewIsSelecting: false,
  selectedElement: None,
}

let actionToString = action => {
  switch action {
  | AddUserMessage({id, _}) => `AddUserMessage(${id})`
  | StreamingStarted({id}) => `StreamingStarted(${id})`
  | TextDeltaReceived({id, text}) => `TextDeltaReceived(${id}, "${text}")`
  | ToolCallReceived({id, toolCall}) => `ToolCallReceived(${id}, ${toolCall.toolName})`
  | MessageCompleted({id}) => `MessageCompleted(${id})`
  | SetPreviewUrl({url}) => `SetPreviewUrl(${url})`
  | SetPreviewDocument(_) => `SetPreviewDocument(document)`
  | ToggleWebPreviewSelection => `ToggleWebPreviewSelection`
  | SetSelectedElement(_) => `SetSelectedElement`
  }
}

let handleEffect = (effect, _state, _dispatch) => {
  switch effect {
  | SendMessageToAPI({message}) => {
      let headers = WebAPI.Headers.make()
      headers->WebAPI.Headers.set(~name="Content-Type", ~value="application/json")

      let body = JSON.stringifyAny({"message": message})->Option.getOr("{}")

      let _ =
        WebAPI.Global.fetch(
          "/api/ask-the-llm/chat",
          ~init={
            method: "POST",
            headers: WebAPI.HeadersInit.fromHeaders(headers),
            body: WebAPI.BodyInit.fromString(body),
          },
        )
        ->Promise.then(response => {
          Console.log2("[Effect] Message sent to API:", response)
          Promise.resolve()
        })
        ->Promise.catch(error => {
          Console.error2("[Effect] Failed to send message to API:", error)
          Promise.resolve()
        })
    }
  }
}

// Helper to extract text content from user message parts
let extractTextFromUserContent = (content: array<UserContentPart.t>): string => {
  content
  ->Array.filterMap(part => {
    switch part {
    | Text({text}) => Some(text)
    | Image({image: _, mediaType: _}) => %todo("add this")
    | Image({image: _}) => %todo("add this")
    | File(_) => %todo("add this")
    }
  })
  ->Array.join(" ")
}

let next = (state, action) => {
  switch action {
  // Add user message to end of messages array
  | AddUserMessage({id, content}) => {
      let message = User({
        id,
        content,
        createdAt: Date.now(),
      })
      let textContent = extractTextFromUserContent(content)
      AskTheLlmReactStatestore.StateReducer.update(
        {
          messages: Array.concat(state.messages, [message]),
          previewDocument: state.previewDocument,
          webPreviewIsSelecting: state.webPreviewIsSelecting,
          selectedElement: state.selectedElement,
        },
        ~sideEffects=[SendMessageToAPI({message: textContent})],
      )
    }

  // Start streaming a new assistant message
  | StreamingStarted({id}) => {
      let message = Assistant(
        Streaming({
          id,
          textBuffer: "",
          toolCalls: [],
          createdAt: Date.now(),
        }),
      )
      AskTheLlmReactStatestore.StateReducer.update({
        messages: Array.concat(state.messages, [message]),
        previewDocument: state.previewDocument,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Append text delta to streaming message
  | TextDeltaReceived({id, text}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | Assistant(Streaming({id: msgId, textBuffer, toolCalls, createdAt})) if msgId == id =>
          Assistant(
            Streaming({
              id: msgId,
              textBuffer: textBuffer ++ text,
              toolCalls,
              createdAt,
            }),
          )
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({
        messages: updatedMessages,
        previewDocument: state.previewDocument,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Add tool call to streaming message
  | ToolCallReceived({id, toolCall}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | Assistant(Streaming({id: msgId, textBuffer, toolCalls, createdAt})) if msgId == id =>
          Assistant(
            Streaming({
              id: msgId,
              textBuffer,
              toolCalls: Array.concat(toolCalls, [toolCall]),
              createdAt,
            }),
          )
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({
        messages: updatedMessages,
        previewDocument: state.previewDocument,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Transition streaming message to completed
  | MessageCompleted({id}) => {
      let updatedMessages = state.messages->Array.map(msg => {
        switch msg {
        | Assistant(Streaming({id: msgId, textBuffer, toolCalls, createdAt})) if msgId == id =>
          // Build content array from streaming state
          let content = {
            // Add text part if buffer has content
            let textParts = if String.length(textBuffer) > 0 {
              [AssistantContentPart.Text({text: textBuffer})]
            } else {
              []
            }

            // Convert tool calls to content parts
            let toolCallParts = toolCalls->Array.map(tc =>
              AssistantContentPart.ToolCall({
                toolCallId: tc.toolCallId,
                toolName: tc.toolName,
                input: tc.input,
              })
            )

            // Concatenate: text first, then tool calls
            Array.concat(textParts, toolCallParts)
          }

          Assistant(
            Completed({
              id: msgId,
              content,
              createdAt,
            }),
          )
        | other => other
        }
      })
      AskTheLlmReactStatestore.StateReducer.update({
        messages: updatedMessages,
        previewDocument: state.previewDocument,
        webPreviewIsSelecting: state.webPreviewIsSelecting,
        selectedElement: state.selectedElement,
      })
    }

  // Set preview URL (clears document)
  | SetPreviewUrl({url}) =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewDocument: {url, document: None},
      webPreviewIsSelecting: state.webPreviewIsSelecting,
      selectedElement: state.selectedElement,
    })

  // Set preview document (keep existing URL)
  | SetPreviewDocument({document}) =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewDocument: {...state.previewDocument, document: document},
      webPreviewIsSelecting: state.webPreviewIsSelecting,
      selectedElement: state.selectedElement,
    })

  // Toggle WebPreview selection mode
  | ToggleWebPreviewSelection =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewDocument: state.previewDocument,
      webPreviewIsSelecting: !state.webPreviewIsSelecting,
      // Clear selected element when turning selection mode ON
      selectedElement: if !state.webPreviewIsSelecting {
        None // Turning ON - clear selection
      } else {
        state.selectedElement // Turning OFF - keep selection
      },
    })

  // Set selected element and reset selection mode
  | SetSelectedElement({selectedElement}) =>
    AskTheLlmReactStatestore.StateReducer.update({
      messages: state.messages,
      previewDocument: state.previewDocument,
      webPreviewIsSelecting: false, // Auto-reset selection mode
      selectedElement: selectedElement,
    })
  }
}

module Selectors = {
  // Get all messages (maintains order)
  let messages = (state: state) => state.messages

  // Get only completed messages
  let completedMessages = (state: state) =>
    state.messages->Array.filter(msg => {
      switch msg {
      | User(_) => true // User messages always complete
      | Assistant(Completed(_)) => true
      | Assistant(Streaming(_)) => false
      }
    })

  // Get streaming messages
  let streamingMessages = (state: state) =>
    state.messages->Array.filterMap(msg => {
      switch msg {
      | Assistant(Streaming(_) as streaming) => Some(streaming)
      | _ => None
      }
    })

  // Check if any message is currently streaming
  let isStreaming = (state: state) =>
    state.messages->Array.some(msg => {
      switch msg {
      | Assistant(Streaming(_)) => true
      | _ => false
      }
    })

  // Get last message
  let lastMessage = (state: state) => state.messages->Array.get(Array.length(state.messages) - 1)

  // Extract stable ID for React keys
  let getMessageId = (msg: message): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    }
  }

  // Get preview document state
  let previewDocument = (state: state) => state.previewDocument

  // Get webPreview selection mode
  let webPreviewIsSelecting = (state: state) => state.webPreviewIsSelecting

  // Get selected element
  let selectedElement = (state: state) => state.selectedElement
}
