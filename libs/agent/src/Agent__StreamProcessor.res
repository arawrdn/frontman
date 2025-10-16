// Stream processor - domain types for LLM stream results
// Processing logic has been moved to Agent__Adapters__Vercel

type toolStatus =
  | Pending
  | Running
  | Completed
  | Error

type toolPart = {
  id: string,
  toolCallId: string,
  toolName: string,
  status: ref<toolStatus>,
  input: option<JSON.t>,
  output: ref<option<string>>,
  error: ref<option<string>>,
  startTime: ref<option<float>>,
  endTime: ref<option<float>>,
}

// Result type returned by stream processor
type processResult = {
  text: string,
  toolCalls: array<toolPart>,
  hasToolCalls: bool,
}
