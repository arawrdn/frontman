# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.RepoAnalyses.RepoAnalysis do
  @moduledoc """
  Ecto schema for immutable repository analysis runs.
  """

  use Ecto.Schema
  import Ecto.Changeset

  alias FrontmanServer.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @resolved_ref_kinds ~w(branch tag commit)
  @repo_name_regex ~r/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/
  @commit_sha_regex ~r/^[0-9a-f]{40}$/i

  schema "repo_analyses" do
    field(:provider, :string, default: "github")
    field(:repo_name, :string)
    field(:requested_ref, :string)
    field(:resolved_ref_kind, :string)
    field(:resolved_ref_name, :string)
    field(:resolved_commit_sha, :string)
    field(:devcontainer_path, :string)
    field(:devcontainer_raw, :map)

    belongs_to(:user, User)

    timestamps(type: :utc_datetime, updated_at: false)
  end

  @type t :: %__MODULE__{}

  @doc """
  Changeset for creating a repository analysis run.

  `user_id` is set explicitly and never cast from attrs.
  """
  @spec create_changeset(t(), Ecto.UUID.t(), map()) :: Ecto.Changeset.t()
  def create_changeset(repo_analysis, attrs) when is_map(attrs) do
    repo_analysis
    |> cast(attrs, [
      :provider,
      :repo_name,
      :requested_ref,
      :resolved_ref_kind,
      :resolved_ref_name,
      :resolved_commit_sha,
      :devcontainer_path,
      :devcontainer_raw
    ])
    |> validate_required([
      :provider,
      :repo_name,
      :resolved_ref_kind,
      :resolved_commit_sha,
      :devcontainer_path,
      :devcontainer_raw,
      :user_id
    ])
    |> validate_inclusion(:provider, ["github"])
    |> validate_format(:repo_name, @repo_name_regex)
    |> validate_inclusion(:resolved_ref_kind, @resolved_ref_kinds)
    |> validate_format(:resolved_commit_sha, @commit_sha_regex)
    |> validate_length(:devcontainer_path, min: 1)
    |> foreign_key_constraint(:user_id)
  end
end
