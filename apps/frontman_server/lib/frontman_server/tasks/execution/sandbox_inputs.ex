defmodule FrontmanServer.Tasks.Execution.SandboxInputs do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.RepoAnalyses

  @default_vm_image "mcr.microsoft.com/devcontainers/base:ubuntu-24.04"
  @default_repo_url "https://github.com/frontman-ai/frontman.git"
  @default_repo_ref "main"

  @sandbox_env_repo_url_key "FRONTMAN_SANDBOX_REPO_URL"
  @sandbox_env_repo_ref_key "FRONTMAN_SANDBOX_REPO_REF"

  @spec build(Scope.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def build(%Scope{} = scope, task_id) when is_binary(task_id) do
    config = Application.get_env(:frontman_server, :sandbox_mvp, [])

    vm_image = Keyword.get(config, :image, @default_vm_image)
    repo_url = Keyword.get(config, :repo_url, @default_repo_url)
    requested_ref = normalize_requested_ref(Keyword.get(config, :repo_ref, @default_repo_ref))

    with {:ok, vm_image} <- normalize_vm_image(vm_image),
         {:ok, repo_url} <- normalize_repo_url(repo_url),
         {:ok, repo_name} <- github_repo_name(repo_url),
         {:ok, analysis} <- analyze_repository(scope, repo_name, requested_ref) do
      {:ok,
       %{
         "name" => sandbox_name(task_id),
         "image" => vm_image,
         "devcontainer" => analysis.devcontainer_raw,
         "env" => sandbox_env(repo_url, analysis.resolved_commit_sha)
       }}
    end
  end

  defp analyze_repository(scope, repo_name, nil) do
    RepoAnalyses.analyze_repository(scope, repo_name)
  end

  defp analyze_repository(scope, repo_name, requested_ref) do
    RepoAnalyses.analyze_repository(scope, repo_name, ref: requested_ref)
  end

  defp normalize_vm_image(image) when is_binary(image) do
    trimmed_image = String.trim(image)

    case trimmed_image do
      "" -> {:error, :invalid_sandbox_vm_image}
      _ -> {:ok, trimmed_image}
    end
  end

  defp normalize_vm_image(_image), do: {:error, :invalid_sandbox_vm_image}

  defp normalize_repo_url(repo_url) when is_binary(repo_url) do
    trimmed_repo_url = String.trim(repo_url)

    case trimmed_repo_url do
      "" -> {:error, :invalid_sandbox_repo_url}
      _ -> {:ok, trimmed_repo_url}
    end
  end

  defp normalize_repo_url(_repo_url), do: {:error, :invalid_sandbox_repo_url}

  defp normalize_requested_ref(ref) when is_binary(ref) do
    trimmed_ref = String.trim(ref)

    case trimmed_ref do
      "" -> nil
      _ -> trimmed_ref
    end
  end

  defp normalize_requested_ref(_ref), do: nil

  defp github_repo_name(repo_url) when is_binary(repo_url) do
    case parse_http_repo_url(repo_url) do
      {:ok, _repo_name} = ok ->
        ok

      {:error, :invalid_sandbox_repo_url} ->
        parse_ssh_repo_url(repo_url)
    end
  end

  defp github_repo_name(_repo_url), do: {:error, :invalid_sandbox_repo_url}

  defp parse_http_repo_url(repo_url) when is_binary(repo_url) do
    uri = URI.parse(repo_url)

    case uri do
      %URI{scheme: scheme, host: host, path: path}
      when scheme in ["http", "https"] and host in ["github.com", "www.github.com"] and
             is_binary(path) ->
        parse_repo_path(path)

      _ ->
        {:error, :invalid_sandbox_repo_url}
    end
  end

  defp parse_ssh_repo_url(repo_url) do
    case Regex.named_captures(
           ~r/^git@github\.com:(?<owner>[^\/]+)\/(?<repo>[^\/]+?)(?:\.git)?$/,
           repo_url
         ) do
      %{"owner" => owner, "repo" => repo} when owner != "" and repo != "" ->
        {:ok, "#{owner}/#{repo}"}

      _ ->
        {:error, :invalid_sandbox_repo_url}
    end
  end

  defp parse_repo_path(path) when is_binary(path) do
    case String.split(path, "/", trim: true) do
      [owner, repo] when owner != "" ->
        repo_name = String.trim_trailing(repo, ".git")

        case repo_name do
          "" -> {:error, :invalid_sandbox_repo_url}
          _ -> {:ok, "#{owner}/#{repo_name}"}
        end

      _ ->
        {:error, :invalid_sandbox_repo_url}
    end
  end

  defp sandbox_env(repo_url, resolved_commit_sha) do
    %{
      @sandbox_env_repo_url_key => repo_url,
      @sandbox_env_repo_ref_key => resolved_commit_sha
    }
  end

  defp sandbox_name(task_id) when is_binary(task_id) do
    "task-" <> String.slice(task_id, 0, 12)
  end
end
