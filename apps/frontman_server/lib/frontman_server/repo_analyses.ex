# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.RepoAnalyses do
  @moduledoc """
  The RepoAnalyses context.

  Runs and persists immutable repository analysis runs for GitHub repositories.
  """

  use Boundary,
    deps: [FrontmanServer, FrontmanServer.Accounts, FrontmanServer.Providers],
    exports: [{RepoAnalysis, []}, {GitHubClient, []}]

  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Providers
  alias FrontmanServer.Repo
  alias FrontmanServer.RepoAnalyses.{Analysis, Analyzer, RepoAnalysis}

  @repo_name_regex ~r/^[A-Za-z0-9_.-]+\/[A-Za-z0-9_.-]+$/

  @type analyze_error ::
          :invalid_repo_name
          | :no_github_oauth_token
          | :unauthorized
          | :repo_not_found
          | :ref_not_found
          | :no_devcontainer
          | :invalid_devcontainer_json
          | {:github_error, pos_integer(), term()}
          | {:network_error, term()}

  @doc """
  Analyzes a GitHub repository and persists one immutable analysis run.
  """
  @spec analyze_repository(Accounts.scope(), String.t()) ::
          {:ok, RepoAnalysis.t()} | {:error, analyze_error() | Ecto.Changeset.t()}
  def analyze_repository(%Scope{} = scope, repo_name) when is_binary(repo_name) do
    analyze_repository(scope, repo_name, nil)
  end

  def analyze_repository(%Scope{}, _repo_name), do: {:error, :invalid_repo_name}

  @spec analyze_repository(Accounts.scope(), String.t(), String.t() | nil) ::
          {:ok, RepoAnalysis.t()} | {:error, analyze_error() | Ecto.Changeset.t()}
  def analyze_repository(%Scope{} = scope, repo_name, requested_ref)
      when is_binary(repo_name) do
    analyze_repository(scope, repo_name, requested_ref, configured_github_client())
  end

  def analyze_repository(%Scope{}, _repo_name, _requested_ref), do: {:error, :invalid_repo_name}

  @spec analyze_repository(Accounts.scope(), String.t(), String.t() | nil, module()) ::
          {:ok, RepoAnalysis.t()} | {:error, analyze_error() | Ecto.Changeset.t()}
  def analyze_repository(%Scope{} = scope, repo_name, requested_ref, github_client)
      when is_binary(repo_name) and is_atom(github_client) do
    with :ok <- validate_repo_name(repo_name),
         :ok <- validate_requested_ref(requested_ref),
         {:ok, github_access_token} <- fetch_github_access_token(scope),
         {:ok, analysis} <-
           Analyzer.analyze_repository(
             github_access_token,
             repo_name,
             requested_ref,
             github_client
           ) do
      persist_analysis(scope, repo_name, analysis)
    end
  end

  def analyze_repository(%Scope{}, _repo_name, _requested_ref, _github_client),
    do: {:error, :invalid_repo_name}

  defp validate_repo_name(repo_name) when is_binary(repo_name) do
    case Regex.match?(@repo_name_regex, repo_name) do
      true -> :ok
      false -> {:error, :invalid_repo_name}
    end
  end

  defp validate_requested_ref(nil), do: :ok

  defp validate_requested_ref(requested_ref) when is_binary(requested_ref) do
    case String.trim(requested_ref) do
      "" -> {:error, :ref_not_found}
      _ -> :ok
    end
  end

  defp validate_requested_ref(_requested_ref), do: {:error, :ref_not_found}

  defp fetch_github_access_token(%Scope{} = scope) do
    case Providers.get_oauth_access_token(scope, "github") do
      {:ok, access_token} ->
        {:ok, access_token}

      {:error, :no_oauth_token} ->
        {:error, :no_github_oauth_token}
    end
  end

  defp configured_github_client do
    Application.fetch_env!(:frontman_server, :repo_analyses_github_client)
  end

  defp persist_analysis(%Scope{} = scope, repo_name, %Analysis{} = analysis) do
    user_id = Accounts.scope_user_id(scope)

    attrs = %{
      provider: "github",
      repo_name: repo_name,
      requested_ref: analysis.requested_ref,
      resolved_ref_kind: analysis.resolved_ref_kind,
      resolved_ref_name: analysis.resolved_ref_name,
      resolved_commit_sha: analysis.resolved_commit_sha,
      devcontainer_path: analysis.devcontainer_path,
      devcontainer_raw: analysis.devcontainer_raw
    }

    %RepoAnalysis{user_id: user_id}
    |> RepoAnalysis.create_changeset(attrs)
    |> Repo.insert()
  end
end
