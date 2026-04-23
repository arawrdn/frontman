# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.RepoAnalyses.GitHubClient.Req do
  @moduledoc """
  Req-backed GitHub API client for repository analysis.
  """

  @behaviour FrontmanServer.RepoAnalyses.GitHubClient

  @api_base_url "https://api.github.com"
  @api_version "2022-11-28"
  @receive_timeout_ms 20_000
  @tag_resolution_depth_max 5

  @impl true
  def get_repository(access_token, repo_name)
      when is_binary(access_token) and is_binary(repo_name) do
    with {:ok, status, body} <- request(access_token, "/repos/#{repo_name}") do
      case body do
        %{"default_branch" => default_branch}
        when is_binary(default_branch) and default_branch != "" ->
          {:ok, %{default_branch: default_branch}}

        _ ->
          {:error, {:github_error, status, body}}
      end
    end
  end

  @impl true
  def resolve_branch(access_token, repo_name, branch_name)
      when is_binary(access_token) and is_binary(repo_name) and is_binary(branch_name) do
    branch_path = encode_segment(branch_name)

    with {:ok, status, body} <-
           request(access_token, "/repos/#{repo_name}/branches/#{branch_path}") do
      case body do
        %{"commit" => %{"sha" => commit_sha}} when is_binary(commit_sha) ->
          {:ok, %{name: resolved_branch_name(body, branch_name), commit_sha: commit_sha}}

        _ ->
          {:error, {:github_error, status, body}}
      end
    end
  end

  @impl true
  def resolve_tag(access_token, repo_name, tag_name)
      when is_binary(access_token) and is_binary(repo_name) and is_binary(tag_name) do
    tag_path = encode_segment(tag_name)

    with {:ok, status, body} <-
           request(access_token, "/repos/#{repo_name}/git/ref/tags/#{tag_path}") do
      case body do
        %{"object" => %{"type" => "commit", "sha" => commit_sha}} when is_binary(commit_sha) ->
          {:ok, %{name: tag_name, commit_sha: commit_sha}}

        %{"object" => %{"type" => "tag", "sha" => tag_sha}} when is_binary(tag_sha) ->
          resolve_tag_commit(access_token, repo_name, tag_sha, tag_name)

        _ ->
          {:error, {:github_error, status, body}}
      end
    end
  end

  @impl true
  def resolve_commit(access_token, repo_name, commit_sha)
      when is_binary(access_token) and is_binary(repo_name) and is_binary(commit_sha) do
    commit_path = encode_segment(commit_sha)

    with {:ok, status, body} <-
           request(access_token, "/repos/#{repo_name}/commits/#{commit_path}") do
      case body do
        %{"sha" => resolved_commit_sha} when is_binary(resolved_commit_sha) ->
          {:ok, %{commit_sha: resolved_commit_sha}}

        _ ->
          {:error, {:github_error, status, body}}
      end
    end
  end

  @impl true
  def get_file_content(access_token, repo_name, path, commit_sha)
      when is_binary(access_token) and is_binary(repo_name) and is_binary(path) and
             is_binary(commit_sha) do
    path_segments = encode_path(path)

    with {:ok, status, body} <-
           request(access_token, "/repos/#{repo_name}/contents/#{path_segments}", ref: commit_sha) do
      case body do
        %{"encoding" => "base64", "content" => encoded_content} when is_binary(encoded_content) ->
          decode_base64_content(encoded_content, status, body)

        _ ->
          {:error, {:github_error, status, body}}
      end
    end
  end

  defp resolve_annotated_tag_commit(_access_token, _repo_name, _tag_sha, depth)
       when depth >= @tag_resolution_depth_max do
    {:error, {:github_error, 500, %{"message" => "tag_resolution_depth_exceeded"}}}
  end

  defp resolve_annotated_tag_commit(access_token, repo_name, tag_sha, depth) do
    tag_path = encode_segment(tag_sha)

    with {:ok, status, body} <- request(access_token, "/repos/#{repo_name}/git/tags/#{tag_path}") do
      case body do
        %{"object" => %{"type" => "commit", "sha" => commit_sha}} when is_binary(commit_sha) ->
          {:ok, commit_sha}

        %{"object" => %{"type" => "tag", "sha" => nested_tag_sha}}
        when is_binary(nested_tag_sha) ->
          resolve_annotated_tag_commit(access_token, repo_name, nested_tag_sha, depth + 1)

        _ ->
          {:error, {:github_error, status, body}}
      end
    end
  end

  defp decode_base64_content(encoded_content, status, body) do
    case Base.decode64(encoded_content, ignore: :whitespace) do
      {:ok, decoded_content} -> {:ok, decoded_content}
      :error -> {:error, {:github_error, status, body}}
    end
  end

  defp resolved_branch_name(
         %{"name" => resolved_name},
         _branch_name
       )
       when is_binary(resolved_name) and resolved_name != "" do
    resolved_name
  end

  defp resolved_branch_name(_body, branch_name), do: branch_name

  defp resolve_tag_commit(access_token, repo_name, tag_sha, tag_name) do
    case resolve_annotated_tag_commit(access_token, repo_name, tag_sha, 0) do
      {:ok, commit_sha} ->
        {:ok, %{name: tag_name, commit_sha: commit_sha}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  defp request(access_token, path, params \\ [])

  defp request(access_token, path, params) when is_binary(access_token) and is_binary(path) do
    options =
      [
        url: "#{@api_base_url}#{path}",
        headers: request_headers(access_token),
        params: params,
        receive_timeout: @receive_timeout_ms,
        retry: false
      ] ++ req_options()

    case Elixir.Req.get(options) do
      {:ok, %Elixir.Req.Response{status: status, body: body}} when status in 200..299 ->
        {:ok, status, body}

      {:ok, %Elixir.Req.Response{status: 401}} ->
        {:error, :unauthorized}

      {:ok, %Elixir.Req.Response{status: 404}} ->
        {:error, :not_found}

      {:ok, %Elixir.Req.Response{status: status, body: body}} ->
        {:error, {:github_error, status, body}}

      {:error, %Elixir.Req.TransportError{reason: reason}} ->
        {:error, {:network_error, reason}}

      {:error, reason} ->
        {:error, {:network_error, reason}}
    end
  end

  defp request_headers(access_token) do
    [
      {"authorization", "Bearer #{access_token}"},
      {"accept", "application/vnd.github+json"},
      {"x-github-api-version", @api_version},
      {"user-agent", "FrontmanServer"}
    ]
  end

  defp encode_path(path) do
    path
    |> String.split("/", trim: true)
    |> Enum.map_join("/", &encode_segment/1)
  end

  defp encode_segment(segment) do
    URI.encode(segment, &URI.char_unreserved?/1)
  end

  defp req_options do
    Application.get_env(:frontman_server, :repo_analyses_github_req_options, [])
  end
end
