// Client tool that asks the user structured questions via a drawer UI.
// The AI calls this tool, the browser shows a question drawer, and the user's
// answer is submitted directly to the server via the tool:submit_result channel event.
// This tool is fire-and-forget from the MCP perspective — no MCP response is sent.

S.enableJson()
module Tool = FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool
type toolResult<'a> = Tool.toolResult<'a>

let name = Tool.ToolNames.question
let visibleToAgent = true
let executionMode = FrontmanAiFrontmanProtocol.FrontmanProtocol__Tool.Interactive

let description = `Use this tool when you need to ask the user questions during execution. This allows you to:
1. Gather user preferences or requirements
2. Clarify ambiguous instructions
3. Get decisions on implementation choices as you work
4. Offer choices to the user about what direction to take.

Usage notes:
- A "Type your own answer" option is always added automatically for every question; don't include "Other" or catch-all options in your choices
- Answers are returned as structured JSON with the question text and selected labels
- If you recommend a specific option, make that the first option and add "(Recommended)" at the end of the label
- Set multiple to true to allow selecting more than one option
- Each question needs a short header (max 30 chars) for the UI stepper
- You can ask multiple questions in a single call — they'll be presented as a step-by-step flow
- Skipped questions return null — infer reasonable defaults for those`

@schema
type questionOption = {
  @s.describe("Display text for this option, 1-5 words, concise")
  label: string,
  @s.describe("Explanation of what this option means")
  description: string,
}

@schema
type questionItem = {
  @s.describe("The full question text to display to the user")
  question: string,
  @s.describe("Short label for the stepper UI, max 30 characters")
  header: string,
  @s.describe("Available choices for the user to select from")
  options: array<questionOption>,
  @s.describe("When true, the user can select multiple options. Defaults to false")
  multiple: option<bool>,
}

@schema
type input = {
  @s.describe("Array of questions to ask the user. They will be presented as a step-by-step flow")
  questions: array<questionItem>,
}

// Re-export output types from the shared types module (avoids circular dependency)
type questionAnswer = Client__Question__Types.toolQuestionAnswer
type output = Client__Question__Types.toolOutput
let outputSchema = Client__Question__Types.toolOutputSchema

// The tool's @schema types and shared types are structurally identical
// but nominally different due to Sury codegen. Safe zero-cost cast.
external toSharedQuestions: array<questionItem> => array<Client__Question__Types.questionItem> = "%identity"

let maxHeaderLength = 30
let maxLabelLength = 30

// Enforce tool schema constraints that models may ignore.
// Truncates header and option labels to their documented limits.
let sanitizeQuestions = (questions: array<questionItem>): array<questionItem> => {
  questions->Array.map(q => {
    let header = switch q.header->String.length > maxHeaderLength {
    | true => q.header->String.slice(~start=0, ~end=maxHeaderLength)
    | false => q.header
    }
    let options = q.options->Array.map(opt => {
      let label = switch opt.label->String.length > maxLabelLength {
      | true => opt.label->String.slice(~start=0, ~end=maxLabelLength)
      | false => opt.label
      }
      {label, description: opt.description}
    })
    {question: q.question, header, options, multiple: q.multiple}
  })
}

// Fire-and-forget: dispatch QuestionAsked to show the drawer, then return immediately.
// The user's answer is submitted to the server via tool:submit_result channel event,
// not via MCP response. The return value here is ignored by the MCP server layer.
let execute = async (input: input, ~taskId: string, ~toolCallId: string): toolResult<output> => {
  let questions = input.questions->sanitizeQuestions->toSharedQuestions
  Client__State__Store.dispatch(
    TaskAction({target: ForTask(taskId), action: QuestionAsked({questions, toolCallId})}),
  )
  // Return value is unused — the MCP server returns None for interactive tools.
  Ok({answers: [], skippedAll: false, cancelled: false})
}
