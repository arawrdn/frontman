defmodule SwarmAi.Message.System do
  @moduledoc "System-role message struct used as high-priority instructions."

  use TypedStruct
  alias SwarmAi.Message.ContentPart

  typedstruct do
    field(:content, [ContentPart.t()], default: [])
  end
end
