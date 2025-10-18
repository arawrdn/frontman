// Core types for Vercel AI SDK
type languageModel
type streamTextResult

type role =
  | @as("user") User
  | @as("assistant") Assistant
  | @as("system") System
  | @as("tool") Tool

// Enable JSON support in Sury
S.enableJson()

// Content part types from Vercel AI SDK
// We use Sury to parse these based on the "type" field
// Put in a module to avoid naming collision with streamPart

module ContentPart = {
  type t =
    | Text({text: string})
    | ToolCall({toolCallId: string, toolName: string, args: JSON.t})
    | ToolResult({toolCallId: string, toolName: string, output: JSON.t})

  let schema = S.union([
    S.object(s => {
      s.tag("type", "text")
      Text({text: s.field("text", S.string)})
    }),
    S.object(s => {
      s.tag("type", "tool-call")
      ToolCall({
        toolCallId: s.field("toolCallId", S.string),
        toolName: s.field("toolName", S.string),
        args: s.field("input", S.json),
      })
    }),
    S.object(s => {
      s.tag("type", "tool-result")
      ToolResult({
        toolCallId: s.field("toolCallId", S.string),
        toolName: s.field("toolName", S.string),
        output: s.field("output", S.json),
      })
    }),
  ])
}

// Message content can be string OR array of parts
// We use JSON.t for the array since we serialize/deserialize with Sury
@unboxed
type content =
  | String(string)
  | Parts(array<JSON.t>)

type message = {
  role: role,
  content: content,
}

// Tool result data
type toolResultData = {
  output: string,
  title: option<string>,
  metadata: option<JSON.t>,
}

// Usage information
type usage = {
  promptTokens: int,
  completionTokens: int,
  totalTokens: int,
}

module AsyncIterableStream = {
  type readableStream<'a>
  type defaultReader<'a>
  type asyncIterator<'a> = AsyncIterator.t<'a>

  // Intersection facade: ReadableStream & AsyncIterable
  type t<'a>

  // Minimal read() result
  type readResult<'a> = {"done": bool, "value": 'a}

  // Views
  external toReadableStream: t<'a> => readableStream<'a> = "%identity"
  external toAsyncIterator: t<'a> => asyncIterator<'a> = "%identity"

  // Constructors (use when the value actually has both facets)
  external fromReadableStream: readableStream<'a> => t<'a> = "%identity"
  external fromAsyncIterator: asyncIterator<'a> => t<'a> = "%identity"

  // Reader ops
  @send external getReader: readableStream<'a> => defaultReader<'a> = "getReader"
  @send external read: defaultReader<'a> => Js.Promise.t<readResult<'a>> = "read"
  @send external releaseLock: defaultReader<'a> => unit = "releaseLock"
}
// Finish reason type from LanguageModelV3FinishReason
type finishReason =
  | @as("stop") Stop // model generated stop sequence
  | @as("length") Length // model generated maximum number of tokens
  | @as("content-filter") ContentFilter // content filter violation stopped the model
  | @as("tool-calls") ToolCalls // model triggered tool calls
  | @as("error") Error // model stopped because of an error
  | @as("other") Other // model stopped for other reasons
  | @as("unknown") Unknown // the model has not transmitted a finish reason

// Stream event types
type streamPart =
  | @as("text-delta") TextDelta({textDelta: string})
  | @as("tool-call") ToolCall({toolCallId: string, toolName: string, args: JSON.t})
  | @as("tool-result") ToolResult({toolCallId: string, toolName: string, result: JSON.t})
  | @as("finish-step") FinishStep({finishReason: finishReason, usage: usage})
  | @as("finish") Finish

// // Get iterator from iterable using Symbol.asyncIterator
// let getAsyncIterator = (_iterable: asyncIterable<'a>): AsyncIterator<'a> => {
//   %raw(`iterable[Symbol.asyncIterator]()`)
// }

// JSON Schema type (from AI SDK's jsonSchema helper)
// This is an opaque type that wraps JSON schemas
type aiSchema

// Tool definition - must match what AI SDK expects
// The Tool type from @ai-sdk/provider-utils uses 'parameters' as an alias for 'inputSchema'
type toolDef = {
  description?: string,
  parameters: aiSchema,
  inputSchema: aiSchema,
  execute: JSON.t => promise<JSON.t>,
}

// Stream text parameters
type streamTextParams = {
  model: languageModel,
  messages: array<message>,
  tools?: Dict.t<toolDef>,
  maxSteps?: int,
}

// Bind streamText function
@module("ai")
external streamText: streamTextParams => promise<streamTextResult> = "streamText"

// Bind fullStream property - returns an async iterable
@get
external fullStream: streamTextResult => AsyncIterableStream.t<streamPart> = "fullStream"

// Get finishReason
@get
external finishReason: streamTextResult => promise<finishReason> = "finishReason"

// Get text from result
@get
external text: streamTextResult => promise<string> = "text"

// Tool call from result
type toolCall = {
  toolCallId: string,
  toolName: string,
  args: JSON.t,
}

// Get tool calls from result
@get
external toolCalls: streamTextResult => promise<array<toolCall>> = "toolCalls"

// Response type containing messages
type response = {messages: array<message>}

// Get response (with messages) from result
@get
external response: streamTextResult => promise<response> = "response"

// jsonSchema helper from AI SDK
@module("ai")
external jsonSchema: JSONSchema.t => aiSchema = "jsonSchema"

// Provider bindings
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
