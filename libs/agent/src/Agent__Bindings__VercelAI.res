// Core types for Vercel AI SDK
type languageModel
type streamTextResult

// Message type
type message = {
  role: string, // "user" | "assistant" | "system"
  content: string,
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
// Stream event types
type streamPart =
  | @as("text-delta") TextDelta({textDelta: string})
  | @as("tool-call") ToolCall({toolCallId: string, toolName: string, args: JSON.t})
  | @as("tool-result") ToolResult({toolCallId: string, toolName: string, result: JSON.t})
  | @as("finish-step") FinishStep({finishReason: string, usage: usage})
  | @as("finish") Finish

// // Get iterator from iterable using Symbol.asyncIterator
// let getAsyncIterator = (_iterable: asyncIterable<'a>): AsyncIterator<'a> => {
//   %raw(`iterable[Symbol.asyncIterator]()`)
// }

// Tool definition
type toolDef = {
  description: option<string>,
  inputSchema: JSONSchema.t,
  execute: JSON.t => promise<JSON.t>,
}

// Stream text parameters
type streamTextParams = {
  model: languageModel,
  messages: array<message>,
  tools: option<Dict.t<toolDef>>,
  maxSteps: option<int>,
}

// Bind streamText function
@module("ai")
external streamText: streamTextParams => promise<streamTextResult> = "streamText"

// Bind fullStream property - returns an async iterable
@get
external fullStream: streamTextResult => AsyncIterableStream.t<streamPart> = "fullStream"

// Get finishReason
@get
external finishReason: streamTextResult => promise<string> = "finishReason"

// Get text from result
@get
external text: streamTextResult => promise<string> = "text"

// Provider bindings
module Anthropic = {
  @module("@ai-sdk/anthropic")
  external anthropic: string => languageModel = "anthropic"

  let claude3Sonnet = () => anthropic("claude-3-5-sonnet-20241022")
}

module OpenAI = {
  @module("@ai-sdk/openai") @val
  external openai: string => languageModel = "openai"

  let gpt4o = () => openai("gpt-4o")
}
