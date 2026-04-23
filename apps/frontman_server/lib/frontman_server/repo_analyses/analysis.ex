# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.RepoAnalyses.Analysis do
  @moduledoc """
  Immutable analysis result returned by the repository analyzer.
  """

  @enforce_keys [
    :requested_ref,
    :resolved_ref_kind,
    :resolved_ref_name,
    :resolved_commit_sha,
    :devcontainer_path,
    :devcontainer_raw
  ]
  defstruct [
    :requested_ref,
    :resolved_ref_kind,
    :resolved_ref_name,
    :resolved_commit_sha,
    :devcontainer_path,
    :devcontainer_raw
  ]

  @type t :: %__MODULE__{
          requested_ref: String.t() | nil,
          resolved_ref_kind: String.t(),
          resolved_ref_name: String.t() | nil,
          resolved_commit_sha: String.t(),
          devcontainer_path: String.t(),
          devcontainer_raw: map()
        }
end
