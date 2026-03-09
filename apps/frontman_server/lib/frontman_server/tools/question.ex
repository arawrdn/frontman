defmodule FrontmanServer.Tools.Question do
  @moduledoc """
  Server-defined interactive tool that asks the user structured questions.

  Unlike regular backend tools, this tool is never executed server-side.
  The ToolExecutor returns `:suspended` immediately, and the TaskChannel
  sends a `session/elicitation` request to the client via ACP. The user's
  answer arrives as a JSON-RPC response and is converted to a tool result
  that resumes the agent.

  This module only provides the tool schema (name, description, parameters)
  so the LLM knows the tool exists and how to call it.
  """

  @behaviour FrontmanServer.Tools.Backend

  @impl true
  def name, do: "question"

  @impl true
  def description do
    """
    Use this tool when you need to ask the user questions during execution. This allows you to:
    1. Gather user preferences or requirements
    2. Clarify ambiguous instructions
    3. Get decisions on implementation choices as you work
    4. Offer choices to the user about what direction to take.

    Usage notes:
    - When `custom` is enabled (default), a "Type your own answer" option is added automatically; don't include "Other" or catch-all options
    - Answers are returned as arrays of labels; set `multiple: true` to allow selecting more than one
    - If you recommend a specific option, make that the first option in the list and add "(Recommended)" at the end of the label
    """
  end

  @impl true
  def parameter_schema do
    %{
      "type" => "object",
      "properties" => %{
        "questions" => %{
          "type" => "array",
          "description" => "Questions to ask",
          "items" => %{
            "type" => "object",
            "properties" => %{
              "question" => %{
                "type" => "string",
                "description" => "Complete question"
              },
              "header" => %{
                "type" => "string",
                "description" => "Very short label (max 30 chars)"
              },
              "options" => %{
                "type" => "array",
                "description" => "Available choices",
                "items" => %{
                  "type" => "object",
                  "properties" => %{
                    "label" => %{
                      "type" => "string",
                      "description" => "Display text (1-5 words, concise)"
                    },
                    "description" => %{
                      "type" => "string",
                      "description" => "Explanation of choice"
                    }
                  },
                  "required" => ["label", "description"]
                }
              },
              "multiple" => %{
                "type" => "boolean",
                "description" => "Allow selecting multiple choices"
              }
            },
            "required" => ["question", "header", "options"]
          }
        }
      },
      "required" => ["questions"]
    }
  end

  @impl true
  def execute(_args, _context) do
    # This should never be called — the tool executor intercepts interactive
    # tools before reaching execute/2. If we get here, something is wrong.
    raise "Question tool execute/2 called directly — this is a bug. " <>
            "Interactive tools must be intercepted by the executor."
  end
end
