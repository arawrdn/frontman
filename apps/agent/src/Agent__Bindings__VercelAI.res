// Core types for Vercel AI SDK

// Abstract types
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

// Stream event types
type streamPart =
  | @as("text-delta") TextDelta({textDelta: string})
  | @as("tool-call") ToolCall({toolCallId: string, toolName: string, args: JSON.t})
  | @as("tool-result") ToolResult({toolCallId: string, toolName: string, result: JSON.t})
  | @as("finish-step") FinishStep({finishReason: string, usage: usage})
  | @as("finish") Finish

// Async iterator type
type asyncIterator<'a>

// Async iterator result
type asyncIteratorResult<'a> = {
  done: bool,
  value: option<'a>,
}

@send
external next: asyncIterator<'a> => promise<asyncIteratorResult<'a>> = "next"

// Tool definition
type toolDef = {
  description: option<string>,
  inputSchema: JSONSchema.t,
  execute: option<JSON.t => promise<JSON.t>>,
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

// Bind fullStream property
@get
external fullStream: streamTextResult => asyncIterator<streamPart> = "fullStream"

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
