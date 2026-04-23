# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.RepoAnalyses.Analyzer do
  @moduledoc """
  Core repository analysis flow:

  - resolve ref to immutable commit SHA
  - detect devcontainer config in deterministic path order
  - parse and return raw devcontainer JSON
  """

  alias FrontmanServer.RepoAnalyses.Analysis

  @devcontainer_paths [
    ".devcontainer/devcontainer.json",
    ".devcontainer.json"
  ]

  @commit_sha_regex ~r/^[0-9a-f]{40}$/i

  @type analysis_result :: Analysis.t()

  @doc """
  Analyzes one repository revision using the provided GitHub access token.
  """
  @spec analyze_repository(String.t(), String.t(), keyword()) ::
          {:ok, analysis_result()} | {:error, term()}
  def analyze_repository(github_access_token, repo_name, opts \\ [])
      when is_binary(github_access_token) and is_binary(repo_name) and is_list(opts) do
    github_client = Keyword.get(opts, :github_client, default_github_client())

    with {:ok, requested_ref} <- normalize_requested_ref(opts),
         {:ok, repository} <- fetch_repository(github_client, github_access_token, repo_name),
         {:ok, resolved_ref} <-
           resolve_requested_ref(
             github_client,
             github_access_token,
             repo_name,
             repository,
             requested_ref
           ),
         {:ok, devcontainer} <-
           detect_devcontainer(
             github_client,
             github_access_token,
             repo_name,
             resolved_ref.commit_sha
           ) do
      {:ok,
       %Analysis{
         requested_ref: requested_ref,
         resolved_ref_kind: resolved_ref.kind,
         resolved_ref_name: resolved_ref.name,
         resolved_commit_sha: resolved_ref.commit_sha,
         devcontainer_path: devcontainer.path,
         devcontainer_raw: devcontainer.raw
       }}
    end
  end

  defp normalize_requested_ref(opts) do
    case Keyword.get(opts, :ref) do
      nil -> {:ok, nil}
      ref when is_binary(ref) and ref != "" -> {:ok, ref}
      _ -> {:error, :ref_not_found}
    end
  end

  defp fetch_repository(github_client, github_access_token, repo_name) do
    case github_client.get_repository(github_access_token, repo_name) do
      {:ok, %{default_branch: default_branch}}
      when is_binary(default_branch) and default_branch != "" ->
        {:ok, %{default_branch: default_branch}}

      {:ok, _repository} ->
        {:error, {:github_error, 500, %{"message" => "invalid_repository_response"}}}

      {:error, :not_found} ->
        {:error, :repo_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_requested_ref(
         github_client,
         github_access_token,
         repo_name,
         %{default_branch: default_branch},
         nil
       ) do
    resolve_branch_ref(github_client, github_access_token, repo_name, default_branch)
  end

  defp resolve_requested_ref(
         github_client,
         github_access_token,
         repo_name,
         _repository,
         requested_ref
       )
       when is_binary(requested_ref) do
    case commit_sha?(requested_ref) do
      true ->
        resolve_commit_ref(github_client, github_access_token, repo_name, requested_ref)

      false ->
        resolve_non_commit_ref(github_client, github_access_token, repo_name, requested_ref)
    end
  end

  defp resolve_non_commit_ref(github_client, github_access_token, repo_name, requested_ref) do
    case resolve_branch_ref(github_client, github_access_token, repo_name, requested_ref) do
      {:ok, resolved_ref} ->
        {:ok, resolved_ref}

      {:error, :ref_not_found} ->
        resolve_tag_ref(github_client, github_access_token, repo_name, requested_ref)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_branch_ref(github_client, github_access_token, repo_name, branch_name) do
    case github_client.resolve_branch(github_access_token, repo_name, branch_name) do
      {:ok, %{name: resolved_name, commit_sha: commit_sha}}
      when is_binary(resolved_name) and is_binary(commit_sha) ->
        {:ok, %{kind: "branch", name: resolved_name, commit_sha: commit_sha}}

      {:ok, _branch} ->
        {:error, {:github_error, 500, %{"message" => "invalid_branch_response"}}}

      {:error, :not_found} ->
        {:error, :ref_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_tag_ref(github_client, github_access_token, repo_name, tag_name) do
    case github_client.resolve_tag(github_access_token, repo_name, tag_name) do
      {:ok, %{name: resolved_name, commit_sha: commit_sha}}
      when is_binary(resolved_name) and is_binary(commit_sha) ->
        {:ok, %{kind: "tag", name: resolved_name, commit_sha: commit_sha}}

      {:ok, _tag} ->
        {:error, {:github_error, 500, %{"message" => "invalid_tag_response"}}}

      {:error, :not_found} ->
        {:error, :ref_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp resolve_commit_ref(github_client, github_access_token, repo_name, commit_sha) do
    case github_client.resolve_commit(github_access_token, repo_name, commit_sha) do
      {:ok, %{commit_sha: resolved_commit_sha}} when is_binary(resolved_commit_sha) ->
        {:ok, %{kind: "commit", name: nil, commit_sha: resolved_commit_sha}}

      {:ok, _commit} ->
        {:error, {:github_error, 500, %{"message" => "invalid_commit_response"}}}

      {:error, :not_found} ->
        {:error, :ref_not_found}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp detect_devcontainer(github_client, github_access_token, repo_name, commit_sha)
       when is_binary(commit_sha) do
    find_devcontainer(
      github_client,
      github_access_token,
      repo_name,
      commit_sha,
      @devcontainer_paths
    )
  end

  defp find_devcontainer(_github_client, _github_access_token, _repo_name, _commit_sha, []) do
    {:error, :no_devcontainer}
  end

  defp find_devcontainer(github_client, github_access_token, repo_name, commit_sha, [
         path | remaining
       ]) do
    case github_client.get_file_content(github_access_token, repo_name, path, commit_sha) do
      {:ok, file_content} ->
        parse_devcontainer(path, file_content)

      {:error, :not_found} ->
        find_devcontainer(github_client, github_access_token, repo_name, commit_sha, remaining)

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp parse_devcontainer(path, file_content) do
    case Jason.decode(file_content) do
      {:ok, raw_devcontainer} when is_map(raw_devcontainer) ->
        {:ok, %{path: path, raw: raw_devcontainer}}

      {:ok, _decoded_non_map} ->
        {:error, :invalid_devcontainer_json}

      {:error, _decode_error} ->
        {:error, :invalid_devcontainer_json}
    end
  end

  defp commit_sha?(ref) when is_binary(ref) do
    Regex.match?(@commit_sha_regex, ref)
  end

  defp default_github_client do
    Application.get_env(
      :frontman_server,
      :repo_analyses_github_client,
      FrontmanServer.RepoAnalyses.GitHubClient.Req
    )
  end
end
