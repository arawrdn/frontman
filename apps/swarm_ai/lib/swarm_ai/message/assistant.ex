defmodule SwarmAi.Message.Assistant do
  @moduledoc "Assistant-role message struct used for model responses."

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
    field(:tool_calls, [SwarmAi.ToolCall.t()], default: [])
    field(:metadata, map(), default: %{})
  end
end
