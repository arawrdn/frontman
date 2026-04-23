defmodule SwarmAi.Message.User do
  @moduledoc "User-role message struct used in the conversation history."

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
  end
end
