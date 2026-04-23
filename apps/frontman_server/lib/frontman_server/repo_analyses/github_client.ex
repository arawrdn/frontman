# Frontman Server
# Copyright (C) 2025 Frontman AI
#
# Licensed under the AGPL-3.0 — see LICENSE for details.
# Additional terms apply — see AI-SUPPLEMENTARY-TERMS.md

defmodule FrontmanServer.RepoAnalyses.GitHubClient do
  @moduledoc """
  Behaviour for GitHub API operations used by repository analysis.
  """

  @type error_reason ::
          :unauthorized
          | :not_found
          | {:github_error, pos_integer(), term()}
          | {:network_error, term()}

  @callback get_repository(access_token :: String.t(), repo_name :: String.t()) ::
              {:ok, %{default_branch: String.t()}} | {:error, error_reason()}

  @callback resolve_branch(
              access_token :: String.t(),
              repo_name :: String.t(),
              branch_name :: String.t()
            ) ::
              {:ok, %{name: String.t(), commit_sha: String.t()}} | {:error, error_reason()}

  @callback resolve_tag(
              access_token :: String.t(),
              repo_name :: String.t(),
              tag_name :: String.t()
            ) ::
              {:ok, %{name: String.t(), commit_sha: String.t()}} | {:error, error_reason()}

  @callback resolve_commit(
              access_token :: String.t(),
              repo_name :: String.t(),
              commit_sha :: String.t()
            ) ::
              {:ok, %{commit_sha: String.t()}} | {:error, error_reason()}

  @callback get_file_content(
              access_token :: String.t(),
              repo_name :: String.t(),
              path :: String.t(),
              commit_sha :: String.t()
            ) :: {:ok, String.t()} | {:error, error_reason()}
end
