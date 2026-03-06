// Types and shared infrastructure for the question tool.
// This module is imported by both Client__Tool__Question and Client__State__StateReducer,
// so it MUST NOT depend on either to avoid circular dependencies.

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

// Schema for parsing question tool input (used by stale-question detection + tool execution)
@schema
type questionInput = {
  questions: array<questionItem>,
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
  toolCallId: string, // needed to submit the result to the server via tool:submit_result
}

// Structured JSON output — the tool result returned to the agent
@schema
type toolQuestionAnswer = {
  @s.describe("The question that was asked")
  question: string,
  @s.describe("Array of selected option labels, or null if the user skipped this question")
  answer: option<array<string>>,
}

@schema
type toolOutput = {
  @s.describe("Answers for each question, in the same order as the input questions")
  answers: array<toolQuestionAnswer>,
  @s.describe("True if the user clicked 'Skip all — decide for me', meaning they want you to use your best judgment for all unanswered questions")
  skippedAll: bool,
  @s.describe("True if the user cancelled, meaning they want you to stop what you're doing")
  cancelled: bool,
}
