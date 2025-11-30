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
  type rec nodeData = {
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
    children: option<array<nodeData>>,
  }

  type t =
    | NoSelection
    | WaitingForSelection
    | SelectedNode(nodeData)
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
    figmaNode: FigmaNode.t,
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
      figmaNode: FigmaNode.NoSelection,
    }
  }
}

// Re-export ACP types for convenience
module ACPTypes = AskTheLlmFrontmanClient.FrontmanClient__ACP__Types

// ============================================================================
// ContentBlock builders for embedded context (ACP embeddedContext)
// ============================================================================

// Build a ResourceLink ContentBlock from SelectedElement
// URI format: file://{path}:{line}:{column}
let selectedElementToContentBlock = (sel: SelectedElement.t): option<ACPTypes.contentBlock> => {
  sel.sourceLocation->Option.map(loc => {
    let uri = `file://${loc.file}:${loc.line->Int.toString}:${loc.column->Int.toString}`
    {
      ACPTypes.type_: "resource_link",
      uri: Some(uri),
      text: None,
      resource: None,
      mimeType: None,
    }
  })
}

// Build a Resource ContentBlock from FigmaNode
// Contains the full Figma node data as JSON
let figmaNodeToContentBlock = (node: FigmaNode.nodeData): ACPTypes.contentBlock => {
  // Serialize figma node to JSON string
  let nodeJson = JSON.stringifyAny({
    "id": node.id,
    "name": node.name,
    "type": node.type_,
    "css": node.css,
    "width": node.width,
    "height": node.height,
    "x": node.x,
    "y": node.y,
    "visible": node.visible,
    "locked": node.locked,
    "children": node.children,
  })->Option.getOr("{}")

  let embeddedResource: ACPTypes.embeddedResource = {
    uri: `figma://node/${node.id}`,
    mimeType: "application/json",
    text: Some(nodeJson),
  }

  {
    ACPTypes.type_: "resource",
    text: None,
    uri: None,
    resource: Some(embeddedResource),
    mimeType: Some("application/json"),
  }
}

// Build ContentBlocks array from Task
// Returns array of ContentBlocks to be added to the prompt
let taskToContentBlocks = (task: Task.t): array<ACPTypes.contentBlock> => {
  let blocks = []

  // Add selectedElement as ResourceLink if available
  let blocks = switch task.selectedElement->Option.flatMap(selectedElementToContentBlock) {
  | Some(block) => Array.concat(blocks, [block])
  | None => blocks
  }

  // Add figmaNode as Resource if available
  let blocks = switch task.figmaNode {
  | FigmaNode.SelectedNode(nodeData) => Array.concat(blocks, [figmaNodeToContentBlock(nodeData)])
  | FigmaNode.NoSelection | FigmaNode.WaitingForSelection => blocks
  }

  blocks
}

// Send prompt function type (from ACP) - now accepts ContentBlocks
type sendPromptFn = (
  string,
  ~additionalBlocks: array<ACPTypes.contentBlock>,
) => promise<result<ACPTypes.promptResult, string>>

// Connection state for the Frontman ACP session
type connectionState =
  | Disconnected
  | Connected(sendPromptFn)

type state = {
  tasks: Dict.t<Task.t>,
  currentTaskId: option<string>,
  connectionState: connectionState,
}
