// Bindings for Vercel AI SDK
// https://sdk.vercel.ai/docs

// Enable JSON support in Sury
S.enableJson()

// ============================================================================
// Core Types
// ============================================================================

type languageModel
type streamTextResult
type aiSchema

type role =
  | @as("user") User
  | @as("assistant") Assistant
  | @as("system") System
  | @as("tool") Tool

type usage = {
  promptTokens: int,
  completionTokens: int,
  totalTokens: int,
}

type finishReason =
  | @as("stop") Stop
  | @as("length") Length
  | @as("content-filter") ContentFilter
  | @as("tool-calls") ToolCalls
  | @as("error") Error
  | @as("other") Other
  | @as("unknown") Unknown

// ============================================================================
// Message Parts
// ============================================================================

// Image/File data - opaque types that accept string | Uint8Array | ArrayBuffer
type imageData
type fileData

module ImageData = {
  external fromString: string => imageData = "%identity"
  external fromUint8Array: Js.TypedArray2.Uint8Array.t => imageData = "%identity"
  external fromArrayBuffer: Js.TypedArray2.ArrayBuffer.t => imageData = "%identity"
}

module FileData = {
  external fromString: string => fileData = "%identity"
  external fromUint8Array: Js.TypedArray2.Uint8Array.t => fileData = "%identity"
  external fromArrayBuffer: Js.TypedArray2.ArrayBuffer.t => fileData = "%identity"
}

module UserPart = {
  @tag("type")
  type t =
    | @as("text") Text({text: string})
    | @as("image") Image({image: imageData, mediaType?: string})
    | @as("file") File({data: fileData, filename?: string, mediaType: string})

  let text = (text: string): t => Text({text: text})

  let imageFromString = (~url: string, ~mediaType=?, ()): t => Image({
    image: ImageData.fromString(url),
    ?mediaType,
  })

  let imageFromUint8Array = (~data: Js.TypedArray2.Uint8Array.t, ~mediaType=?, ()): t => Image({
    image: ImageData.fromUint8Array(data),
    ?mediaType,
  })

  let imageFromArrayBuffer = (~data: Js.TypedArray2.ArrayBuffer.t, ~mediaType=?, ()): t => Image({
    image: ImageData.fromArrayBuffer(data),
    ?mediaType,
  })

  let fileFromString = (~url: string, ~mediaType, ~filename=?, ()): t => File({
    data: FileData.fromString(url),
    mediaType,
    ?filename,
  })

  let fileFromUint8Array = (
    ~data: Js.TypedArray2.Uint8Array.t,
    ~mediaType,
    ~filename=?,
    (),
  ): t => File({data: FileData.fromUint8Array(data), mediaType, ?filename})

  let fileFromArrayBuffer = (
    ~data: Js.TypedArray2.ArrayBuffer.t,
    ~mediaType,
    ~filename=?,
    (),
  ): t => File({data: FileData.fromArrayBuffer(data), mediaType, ?filename})
}

module AssistantPart = {
  @tag("type")
  type t =
    | @as("text") Text({text: string})
    | @as("tool-call") ToolCall({toolCallId: string, toolName: string, args: JSON.t})

  let text = (text: string): t => Text({text: text})

  let toolCall = (~toolCallId, ~toolName, ~args): t => ToolCall({toolCallId, toolName, args})
}

module ToolResultPart = {
  // Tool result output types
  type toolResultContentPart =
    | @as("text") TextContent({text: string})
    | @as("media") MediaContent({data: string, mediaType: string})

  @tag("type")
  type toolResultOutput =
    | @as("text") Text({value: string})
    | @as("json") Json({value: JSON.t})
    | @as("error-text") ErrorText({value: string})
    | @as("error-json") ErrorJson({value: JSON.t})
    | @as("content") Content({value: array<toolResultContentPart>})

  @tag("type")
  type t =
    | @as("tool-result")
    ToolResult({
        toolCallId: string,
        toolName: string,
        output: toolResultOutput,
        providerOptions?: JSON.t,
      })

  let textOutput = (value: string): toolResultOutput => Text({value: value})
  let jsonOutput = (value: JSON.t): toolResultOutput => Json({value: value})
  let errorText = (value: string): toolResultOutput => ErrorText({value: value})
  let errorJson = (value: JSON.t): toolResultOutput => ErrorJson({value: value})

  let create = (~toolCallId, ~toolName, ~output, ~providerOptions=?, ()): t => ToolResult({
    toolCallId,
    toolName,
    output,
    ?providerOptions,
  })
}

// ============================================================================
// Message Types
// ============================================================================

@unboxed
type userContent =
  | String(string)
  | Parts(array<UserPart.t>)

@unboxed
type assistantContent =
  | String(string)
  | Parts(array<AssistantPart.t>)

@unboxed
type toolContent = Parts(array<ToolResultPart.t>)

type systemModelMessage = {
  role: role,
  content: string,
}

type userModelMessage = {
  role: role,
  content: userContent,
}

type assistantModelMessage = {
  role: role,
  content: assistantContent,
}

type toolModelMessage = {
  role: role,
  content: toolContent,
}

@tag("role")
type modelMessage =
  | @as("system") SystemMessage(systemModelMessage)
  | @as("user") UserMessage(userModelMessage)
  | @as("assistant") AssistantMessage(assistantModelMessage)
  | @as("tool") ToolMessage(toolModelMessage)

// Legacy message type (used by current implementation)
@unboxed
type content =
  | String(string)
  | Parts(array<JSON.t>)

type message = {
  role: role,
  content: content,
}

// ============================================================================
// Streaming
// ============================================================================

module AsyncIterableStream = {
  type readableStream<'a>
  type defaultReader<'a>
  type asyncIterator<'a> = AsyncIterator.t<'a>
  type t<'a>
  type readResult<'a> = {"done": bool, "value": 'a}

  external toReadableStream: t<'a> => readableStream<'a> = "%identity"
  external toAsyncIterator: t<'a> => asyncIterator<'a> = "%identity"
  external fromReadableStream: readableStream<'a> => t<'a> = "%identity"
  external fromAsyncIterator: asyncIterator<'a> => t<'a> = "%identity"

  @send external getReader: readableStream<'a> => defaultReader<'a> = "getReader"
  @send external read: defaultReader<'a> => Js.Promise.t<readResult<'a>> = "read"
  @send external releaseLock: defaultReader<'a> => unit = "releaseLock"
}

type streamPart =
  | @as("text-delta") TextDelta({textDelta: string})
  | @as("tool-call") ToolCall({toolCallId: string, toolName: string, args: JSON.t})
  | @as("finish-step") FinishStep({finishReason: finishReason, usage: usage})
  | @as("finish") Finish

@get external fullStream: streamTextResult => AsyncIterableStream.t<streamPart> = "fullStream"
@get external finishReason: streamTextResult => promise<finishReason> = "finishReason"
@get external text: streamTextResult => promise<string> = "text"

// ============================================================================
// Tools
// ============================================================================

type toolDef = {
  description?: string,
  parameters: aiSchema,
  inputSchema: aiSchema,
  execute?: JSON.t => promise<JSON.t>,
}

type toolCall = {
  toolCallId: string,
  toolName: string,
  args: JSON.t,
}

@get external toolCalls: streamTextResult => promise<array<toolCall>> = "toolCalls"

@module("ai") external jsonSchema: JSONSchema.t => aiSchema = "jsonSchema"

// ============================================================================
// API Functions
// ============================================================================

type streamTextParams = {
  model: languageModel,
  messages: array<message>,
  tools?: Dict.t<toolDef>,
  maxSteps?: int,
}

type response = {messages: array<message>}

@module("ai") external streamText: streamTextParams => promise<streamTextResult> = "streamText"
@get external response: streamTextResult => promise<response> = "response"

// ============================================================================
// Providers
// ============================================================================

module Anthropic = {
  @module("@ai-sdk/anthropic")
  external anthropic: string => languageModel = "anthropic"

  let claude3Sonnet = () => anthropic("claude-3-5-sonnet-20241022")
}

module OpenAI = {
  @module("@ai-sdk/openai") @scope("openai")
  external model: string => languageModel = "chat"

  let gpt4o = () => model("gpt-4o")
}
