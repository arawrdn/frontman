defmodule FrontmanServer.Tasks.Execution.SandboxInputs do
  @moduledoc false

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.RepoAnalyses

  @sandbox_env_repo_url_key "FRONTMAN_SANDBOX_REPO_URL"
  @sandbox_env_repo_ref_key "FRONTMAN_SANDBOX_REPO_REF"
  @sandbox_repo_name "frontman-ai/frontman"
  @sandbox_requested_ref "main"

  @spec build(Scope.t(), String.t()) :: {:ok, map()} | {:error, term()}
  def build(%Scope{} = scope, task_id) when is_binary(task_id) do
    config =
      Application.fetch_env!(:frontman_server, :sandbox)
      |> Keyword.fetch!(:bootstrap)

    vm_image = Keyword.fetch!(config, :image)
    repo_name = @sandbox_repo_name
    requested_ref = @sandbox_requested_ref
    repo_url = repo_url(repo_name)

    with {:ok, vm_image} <- normalize_vm_image(vm_image),
         {:ok, analysis} <- analyze_repository(scope, repo_name, requested_ref) do
      {
        :ok,
        %{
          "name" => sandbox_name(task_id),
          "image" => vm_image,
          "devcontainer" => analysis.devcontainer_raw,
          "env" => sandbox_env(repo_url, analysis.resolved_commit_sha)
        }
      }
    end
  end

  defp analyze_repository(scope, repo_name, requested_ref) do
    RepoAnalyses.analyze_repository(scope, repo_name, requested_ref)
  end

  defp normalize_vm_image(image) when is_binary(image) do
    trimmed_image = String.trim(image)

    case trimmed_image do
      "" -> {:error, :invalid_sandbox_vm_image}
      _ -> {:ok, trimmed_image}
    end
  end

  defp normalize_vm_image(_image), do: {:error, :invalid_sandbox_vm_image}

  defp repo_url(repo_name) when is_binary(repo_name) do
    "https://github.com/#{repo_name}.git"
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
