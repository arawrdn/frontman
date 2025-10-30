open Vitest

module Reducer = Client__State__StateReducer
module UserContentPart = Reducer.UserContentPart
module AssistantContentPart = Reducer.AssistantContentPart

describe("Client State Reducer", () => {
  test("initial state has no messages", t => {
    let state = Reducer.defaultState
    t->expect(state.messages->Array.length)->Expect.toBe(0)
  })

  test("AddUserMessage appends user message", t => {
    let state = Reducer.defaultState
    let action = Reducer.AddUserMessage({
      id: "user-1",
      content: [UserContentPart.text("Hello")],
    })

    let (nextState, _effects) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(1)

    switch nextState.messages->Array.get(0) {
    | Some(User({id, content, _})) => {
        t->expect(id)->Expect.toBe("user-1")
        t->expect(content->Array.length)->Expect.toBe(1)
      }
    | _ => t->expect("Got User message")->Expect.toBe("Expected User message")
    }
  })

  test("StreamingStarted creates assistant Streaming message", t => {
    let state = Reducer.defaultState
    let action = Reducer.StreamingStarted({id: "assistant-1"})

    let (nextState, _effects) = Reducer.next(state, action)

    t->expect(nextState.messages->Array.length)->Expect.toBe(1)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Streaming({id, textBuffer, toolCalls, _}))) => {
        t->expect(id)->Expect.toBe("assistant-1")
        t->expect(textBuffer)->Expect.toBe("")
        t->expect(toolCalls->Array.length)->Expect.toBe(0)
      }
    | _ => t->expect("Got Streaming message")->Expect.toBe("Expected Streaming message")
    }
  })

  test("TextDeltaReceived appends to textBuffer", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Hello",
            toolCalls: [],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let action = Reducer.TextDeltaReceived({id: "assistant-1", text: " world"})
    let (nextState, _effects) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Streaming({textBuffer, _}))) =>
      t->expect(textBuffer)->Expect.toBe("Hello world")
    | _ => t->expect("Got updated text")->Expect.toBe("Expected updated text")
    }
  })

  test("MessageCompleted transitions to Completed variant", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Hello world",
            toolCalls: [],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let action = Reducer.MessageCompleted({
      id: "assistant-1",
    })
    let (nextState, _effects) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) => {
        t->expect(content->Array.length)->Expect.toBe(1)
        // Verify content was built from textBuffer
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("messages maintain order", t => {
    let state = Reducer.defaultState

    // Add user message
    let (state, _) = Reducer.next(
      state,
      AddUserMessage({
        id: "user-1",
        content: [UserContentPart.text("Hi")],
      }),
    )

    // Start assistant streaming
    let (state, _) = Reducer.next(state, StreamingStarted({id: "assistant-1"}))

    // Add text delta
    let (state, _) = Reducer.next(
      state,
      TextDeltaReceived({id: "assistant-1", text: "Hello"}),
    )

    // Complete message
    let (state, _) = Reducer.next(
      state,
      MessageCompleted({
        id: "assistant-1",
      }),
    )

    t->expect(state.messages->Array.length)->Expect.toBe(2)

    // Verify order: User first, then Assistant
    switch (state.messages->Array.get(0), state.messages->Array.get(1)) {
    | (Some(User(_)), Some(Assistant(_))) => t->expect(true)->Expect.toBe(true)
    | _ => t->expect("Messages in order")->Expect.toBe("Messages not in order")
    }
  })

  test("Selectors.isStreaming detects streaming messages", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "",
            toolCalls: [],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(true)
  })

  test("Selectors.isStreaming false when no streaming", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Completed({
            id: "assistant-1",
            content: [AssistantContentPart.text("Done")],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    t->expect(Reducer.Selectors.isStreaming(state))->Expect.toBe(false)
  })

  test("ToolCallReceived adds tool call to streaming message", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "assistant-1",
            textBuffer: "Calling tool...",
            toolCalls: [],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let toolCall: Reducer.toolCall = {
      toolCallId: "call-123",
      toolName: "search",
      input: JSON.Encode.object(dict{}),
    }

    let action = Reducer.ToolCallReceived({id: "assistant-1", toolCall})
    let (nextState, _effects) = Reducer.next(state, action)

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Streaming({toolCalls, _}))) => {
        t->expect(toolCalls->Array.length)->Expect.toBe(1)
        switch toolCalls->Array.get(0) {
        | Some(tc) => t->expect(tc.toolName)->Expect.toBe("search")
        | None => t->expect("Got tool call")->Expect.toBe("Expected tool call")
        }
      }
    | _ => t->expect("Got tool call")->Expect.toBe("Expected tool call")
    }
  })
})

describe("Client State Reducer - MessageCompleted Content Conversion", () => {
  test("handles empty textBuffer correctly", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "msg-2",
            textBuffer: "",
            toolCalls: [],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "msg-2"}))

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) =>
      t->expect(content->Array.length)->Expect.toBe(0)
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("converts toolCalls to ToolCall content parts", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "msg-3",
            textBuffer: "Listing files",
            toolCalls: [
              {
                toolCallId: "call_1",
                toolName: "listFiles",
                input: JSON.parseOrThrow(`{"dir": "."}`),
              },
            ],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "msg-3"}))

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({content, _}))) => {
        t->expect(content->Array.length)->Expect.toBe(2)

        // First should be text
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) =>
          t->expect(text)->Expect.toBe("Listing files")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }

        // Second should be tool call
        switch content->Array.get(1) {
        | Some(AssistantContentPart.ToolCall({toolCallId, toolName, _})) => {
            t->expect(toolCallId)->Expect.toBe("call_1")
            t->expect(toolName)->Expect.toBe("listFiles")
          }
        | _ => t->expect("Got tool call")->Expect.toBe("Expected tool call")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })

  test("preserves message ID during streaming to completed transition", t => {
    let state: Reducer.state = {
      previewDocument: {
        url: "https://example.com",
        document: None,
      },
      webPreviewIsSelecting: false,
      selectedElement: None,
      messages: [
        Assistant(
          Streaming({
            id: "stable-id-123",
            textBuffer: "Test",
            toolCalls: [],
            createdAt: 0.0,
          }),
        ),
      ],
    }

    let (nextState, _) = Reducer.next(state, MessageCompleted({id: "stable-id-123"}))

    switch nextState.messages->Array.get(0) {
    | Some(Assistant(Completed({id, _}))) => t->expect(id)->Expect.toBe("stable-id-123")
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })
})

describe("Client State Reducer - Streaming Flow", () => {
  test("full streaming lifecycle maintains stable ID", t => {
    let state = Reducer.defaultState

    // 1. Start streaming
    let (state, _) = Reducer.next(state, StreamingStarted({id: "text-abc"}))

    // 2. Receive text deltas
    let (state, _) = Reducer.next(state, TextDeltaReceived({id: "text-abc", text: "Hello"}))
    let (state, _) = Reducer.next(state, TextDeltaReceived({id: "text-abc", text: " world"}))

    // 3. Complete message
    let (state, _) = Reducer.next(state, MessageCompleted({id: "text-abc"}))

    // Verify: Message ID stayed stable throughout
    switch state.messages->Array.get(0) {
    | Some(Assistant(Completed({id, content, _}))) => {
        t->expect(id)->Expect.toBe("text-abc")
        switch content->Array.get(0) {
        | Some(AssistantContentPart.Text({text})) => t->expect(text)->Expect.toBe("Hello world")
        | _ => t->expect("Got text content")->Expect.toBe("Expected text content")
        }
      }
    | _ => t->expect("Got Completed message")->Expect.toBe("Expected Completed message")
    }
  })
})

describe("Client State Reducer - Selectors", () => {
  test("getMessageId selector works for all message types", t => {
    let userMsg = Reducer.User({
      id: "user-1",
      content: [],
      createdAt: 0.0,
    })

    let streamingMsg = Reducer.Assistant(
      Reducer.Streaming({
        id: "streaming-1",
        textBuffer: "",
        toolCalls: [],
        createdAt: 0.0,
      }),
    )

    let completedMsg = Reducer.Assistant(
      Reducer.Completed({
        id: "completed-1",
        content: [],
        createdAt: 0.0,
      }),
    )

    t->expect(Reducer.Selectors.getMessageId(userMsg))->Expect.toBe("user-1")
    t->expect(Reducer.Selectors.getMessageId(streamingMsg))->Expect.toBe("streaming-1")
    t->expect(Reducer.Selectors.getMessageId(completedMsg))->Expect.toBe("completed-1")
  })
})
