S.enableJson()
// Part types - opaque construction for type safety

// ============ TextPart ============

module TextPart = {
  @schema
  type t = {
    text: string,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~text, ~metadata=None) => {
    {text, metadata}
  }

  let getText = (part: t): string => part.text
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ FilePart ============

module File = {
  @schema
  type t = {
    name: option<string>,
    mimeType: string,
    bytes: string, // base64 encoded
  }

  let make = (~name=None, ~mimeType, ~bytes) => {
    {name, mimeType, bytes}
  }

  let getName = (file: t): option<string> => file.name
  let getMimeType = (file: t): string => file.mimeType
  let getBytes = (file: t): string => file.bytes
}

module FilePart = {
  @schema
  type t = {
    file: File.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~file, ~metadata=None) => {
    {file, metadata}
  }

  let getFile = (part: t): File.t => part.file
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ DataPart ============

module DataPart = {
  @schema
  type t = {
    data: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~data, ~metadata=None) => {
    {data, metadata}
  }

  let getData = (part: t): JSON.t => part.data
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ ToolUsePart ============

module ToolUsePart = {
  @schema
  type t = {
    toolCallId: string,
    toolName: string,
    args: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~toolCallId, ~toolName, ~args, ~metadata=None) => {
    {toolCallId, toolName, args, metadata}
  }

  let getToolCallId = (part: t): string => part.toolCallId
  let getToolName = (part: t): string => part.toolName
  let getArgs = (part: t): JSON.t => part.args
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ ToolResultPart ============

module ToolResultPart = {
  @schema
  type t = {
    toolCallId: string,
    toolName: string,
    result: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~toolCallId, ~toolName, ~result, ~metadata=None) => {
    {toolCallId, toolName, result, metadata}
  }

  let getToolCallId = (part: t): string => part.toolCallId
  let getToolName = (part: t): string => part.toolName
  let getResult = (part: t): JSON.t => part.result
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ Part Union ============

@schema 
type t =
  | @as("text") Text(TextPart.t)
  | @as("file") File(FilePart.t)
  | @as("data") Data(DataPart.t)
  | @as("toolUse") ToolUse(ToolUsePart.t)
  | @as("toolResult") ToolResult(ToolResultPart.t)

// Convenience constructors
let text = (~text, ~metadata=None) => Text(TextPart.make(~text, ~metadata))
let file = (~file, ~metadata=None) => File(FilePart.make(~file, ~metadata))
let data = (~data, ~metadata=None) => Data(DataPart.make(~data, ~metadata))
let toolUse = (~toolCallId, ~toolName, ~args, ~metadata=None) =>
  ToolUse(ToolUsePart.make(~toolCallId, ~toolName, ~args, ~metadata))
let toolResult = (~toolCallId, ~toolName, ~result, ~metadata=None) =>
  ToolResult(ToolResultPart.make(~toolCallId, ~toolName, ~result, ~metadata))
