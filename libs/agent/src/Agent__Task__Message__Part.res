// Part types - opaque construction for type safety

// ============ TextPart ============

module TextPart = {
  type t = Text(string)
}

// ============ FilePart ============

module FilePart = {
  type data =
    | Data({image: string, mediaType: option<string>})
    | Url({image: WebAPI.URLAPI.url, mediaType: option<string>})

  type t = {
    fileName: option<string>,
    mediaType: string,
    data: data,
  }
}
module ImagePart = {
  type t =
    | Data({image: string, mediaType: option<string>})
    | Url({image: WebAPI.URLAPI.url, mediaType: option<string>})
}

// ============ DataPart ============

module DataPart = {
  type t = {
    data: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }
}

// ============ ToolUsePart ============

module ToolCallPart = {
  type t = {
    toolCallId: string,
    toolName: string,
    args: JSON.t,
  }
}

// ============ ToolResultPart ============

module ToolResultPart = {
  module Content = {
    type t = Text(string) | Media({data: string, mediaType: string})
  }

  module Output = {
    type t =
      | Text(string)
      | JSON(JSON.t)
      | ErrorText(string)
      | ErrorJSON(JSON.t)
      | Content(array<Content.t>)
  }

  type t = {
    toolCallId: string,
    toolName: string,
    output: Output.t,
    providerOptions: option<JSON.t>,
  }
}

// ============ Part Union ============

type t =
  | Text(TextPart.t)
  | File(FilePart.t)
  | Data(DataPart.t)
  | ToolCall(ToolCallPart.t)
  | ToolResult(ToolResultPart.t)
