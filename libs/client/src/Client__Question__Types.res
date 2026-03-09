// Shared types for the question/elicitation UI.
// Used by the task reducer, question drawer, and question tool block components.

S.enableJson()

@schema
type questionOption = {
  label: string,
  description: string,
}

@schema
type questionItem = {
  question: string,
  header: string,
  options: array<questionOption>,
  multiple: option<bool>,
}

// Per-question answer state (used by the reducer/UI)
type questionAnswer =
  | Answered(array<string>)
  | CustomText(string)
  | Skipped

type pendingQuestion = {
  questions: array<questionItem>,
  answers: Dict.t<questionAnswer>, // keyed by string index ("0", "1", ...)
  currentStep: int,
  requestId: string, // JSON-RPC request id from session/elicitation — used to send the response
}
