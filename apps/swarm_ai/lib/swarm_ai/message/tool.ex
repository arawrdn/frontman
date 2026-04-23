defmodule SwarmAi.Message.Tool do
  @moduledoc "Tool-role message struct returned from tool invocations."

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
    field(:tool_call_id, String.t(), enforce: true)
    field(:name, String.t(), enforce: true)
    field(:metadata, map(), default: %{})
  end
end
