defmodule FrontmanServer.Test.Support.RepoAnalyses.StaticGitHubClient do
  @moduledoc false

  @behaviour FrontmanServer.RepoAnalyses.GitHubClient

  @default_commit_sha String.duplicate("a", 40)

  @devcontainer_json Jason.encode!(%{
                       "name" => "Frontman Dev",
                       "image" => "mcr.microsoft.com/devcontainers/base:ubuntu-24.04",
                       "forwardPorts" => [4000]
                     })

  @impl true
  def get_repository(_access_token, _repo_name) do
    {:ok, %{default_branch: "main"}}
  end

  @impl true
  def resolve_branch(_access_token, _repo_name, branch_name) do
    {:ok, %{name: branch_name, commit_sha: @default_commit_sha}}
  end

  @impl true
  def resolve_tag(_access_token, _repo_name, _tag_name) do
    {:error, :not_found}
  end

  @impl true
  def resolve_commit(_access_token, _repo_name, commit_sha) do
    {:ok, %{commit_sha: commit_sha}}
  end

  @impl true
  def get_file_content(_access_token, _repo_name, ".devcontainer/devcontainer.json", _commit_sha) do
    {:ok, @devcontainer_json}
  end

  def get_file_content(_access_token, _repo_name, _path, _commit_sha) do
    {:error, :not_found}
  end
end
