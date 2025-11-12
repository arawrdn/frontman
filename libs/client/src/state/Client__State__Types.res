// State type definitions - extracted to avoid circular dependencies
module Agent = AskTheLlmAgent.Agent
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel
module Nextjs__Types = AskTheLlmNextjs.Nextjs__Types
module UserContentPart = Vercel.UserPart
module AssistantContentPart = Vercel.AssistantPart

module Message = {
  type toolCallState =
    | InputStreaming
    | InputAvailable
    | OutputAvailable
    | OutputError

  type assistantMessage =
    | Streaming({id: string, textBuffer: string, createdAt: float})
    | Completed({id: string, content: array<AssistantContentPart.t>, createdAt: float})

  type toolCall = {
    id: string,
    toolName: string,
    state: toolCallState,
    inputBuffer: string,
    input: option<JSON.t>,
    result: option<JSON.t>,
    errorText: option<string>,
    createdAt: float,
  }

  type t =
    | User({id: string, content: array<UserContentPart.t>, createdAt: float})
    | Assistant(assistantMessage)
    | ToolCall(toolCall)

  let getId = (msg: t): string => {
    switch msg {
    | User({id, _}) => id
    | Assistant(Streaming({id, _})) => id
    | Assistant(Completed({id, _})) => id
    | ToolCall({id, _}) => id
    }
  }
}

module SelectedElement = {
  type t = {
    element: WebAPI.DOMAPI.element,
    selector: option<string>,
    screenshot: option<string>,
    sourceLocation: option<Client__Types.SourceLocation.t>,
  }

  let make = (
    ~element: WebAPI.DOMAPI.element,
    ~selector: option<string>,
    ~screenshot: option<string>,
    ~sourceLocation: option<Client__Types.SourceLocation.t>,
  ) => {
    {
      element,
      selector,
      screenshot,
      sourceLocation,
    }
  }

  // Helper to convert to API-safe format (without DOM element reference)
  let withoutElement = (selected: option<t>): option<Nextjs__Types.selectedElement> => {
    selected->Option.map(sel => {
      let result: Nextjs__Types.selectedElement = {
        selector: sel.selector,
        screenshot: sel.screenshot,
        sourceLocation: sel.sourceLocation->Option.map(Client__Types.SourceLocation.toNextJsType),
      }
      result
    })
  }
}

module FigmaNode = {
  type rec t = {
    id: string,
    name: string,
    @as("type") type_: string,
    css: option<Dict.t<string>>,
    width: option<float>,
    height: option<float>,
    x: option<float>,
    y: option<float>,
    visible: option<bool>,
    locked: option<bool>,
    children: option<array<t>>,
  }
}

module Task = {
  type previewFrame = {
    url: string,
    contentDocument: option<WebAPI.DOMAPI.document>,
    contentWindow: option<WebAPI.DOMAPI.window>,
    errors: array<Client__Types.consoleError>,
  }

  type t = {
    id: string,
    title: string,
    messages: Dict.t<Message.t>,
    createdAt: float,
    lastMessageAt: option<float>,
    previewFrame: previewFrame,
    webPreviewIsSelecting: bool,
    selectedElement: option<SelectedElement.t>,
    figmaNode: option<FigmaNode.t>,
    figmaNodeWaiting: bool,
  }

  let make = (~title: string, ~previewUrl: string, ~messages=Dict.make()): t => {
    let newId = WebAPI.Global.crypto->WebAPI.Crypto.randomUUID
    let timestamp = Date.now()

    // Normalize title: trim, truncate, add ellipsis, or default
    let normalizedTitle = switch String.trim(title) {
    | "" => "New Chat"
    | text => {
        let sliced = text->String.slice(~start=0, ~end=50)
        String.length(sliced) < String.length(text) ? sliced ++ "..." : sliced
      }
    }
    {
      id: newId,
      title: normalizedTitle,
      messages,
      createdAt: timestamp,
      previewFrame: {url: previewUrl, contentDocument: None, contentWindow: None, errors: []},
      lastMessageAt: None,
      webPreviewIsSelecting: false,
      selectedElement: None,
      figmaNode: None,
      figmaNodeWaiting: false,
    }
  }
}

type state = {
  tasks: Dict.t<Task.t>,
  currentTaskId: option<string>,
}
