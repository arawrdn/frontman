defmodule FrontmanServer.Tasks.Execution.SandboxInputsTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.Execution.SandboxInputs
  alias FrontmanServer.Test.Support.RepoAnalyses.StaticGitHubClient

  @default_vm_image "ghcr.io/frontman-ai/frontman-dev:stable"

  setup do
    scope = user_scope_fixture()

    original_sandbox_mvp_config = Application.get_env(:frontman_server, :sandbox_mvp, [])

    original_repo_analyses_client =
      Application.get_env(:frontman_server, :repo_analyses_github_client)

    Application.put_env(:frontman_server, :repo_analyses_github_client, StaticGitHubClient)

    {:ok, _oauth_token} =
      Providers.upsert_oauth_token(scope, "github", "sandbox-inputs-github-token", nil, nil)

    on_exit(fn ->
      Application.put_env(:frontman_server, :sandbox_mvp, original_sandbox_mvp_config)

      case original_repo_analyses_client do
        nil -> Application.delete_env(:frontman_server, :repo_analyses_github_client)
        client -> Application.put_env(:frontman_server, :repo_analyses_github_client, client)
      end
    end)

    %{scope: scope, task_id: Ecto.UUID.generate()}
  end

  describe "build/2" do
    test "uses configured VM image and keeps analyzed devcontainer raw", %{
      scope: scope,
      task_id: task_id
    } do
      put_sandbox_mvp_config(
        image: @default_vm_image,
        repo_url: "https://github.com/frontman-ai/frontman.git",
        repo_ref: "main"
      )

      assert {:ok, env_spec} = SandboxInputs.build(scope, task_id)

      assert env_spec["image"] == @default_vm_image

      assert env_spec["devcontainer"]["image"] ==
               "mcr.microsoft.com/devcontainers/base:ubuntu-24.04"

      assert env_spec["env"]["FRONTMAN_SANDBOX_REPO_URL"] ==
               "https://github.com/frontman-ai/frontman.git"

      assert env_spec["env"]["FRONTMAN_SANDBOX_REPO_REF"] == String.duplicate("a", 40)
      assert String.starts_with?(env_spec["name"], "task-")
    end

    test "accepts ssh GitHub repo URLs", %{scope: scope, task_id: task_id} do
      put_sandbox_mvp_config(
        image: @default_vm_image,
        repo_url: "git@github.com:frontman-ai/frontman.git",
        repo_ref: "main"
      )

      assert {:ok, env_spec} = SandboxInputs.build(scope, task_id)

      assert env_spec["env"]["FRONTMAN_SANDBOX_REPO_URL"] ==
               "git@github.com:frontman-ai/frontman.git"
    end

    test "returns invalid_sandbox_repo_url when sandbox repo URL is not a GitHub URL", %{
      scope: scope,
      task_id: task_id
    } do
      put_sandbox_mvp_config(
        image: @default_vm_image,
        repo_url: "https://gitlab.com/frontman-ai/frontman.git"
      )

      assert {:error, :invalid_sandbox_repo_url} = SandboxInputs.build(scope, task_id)
    end

    test "returns no_github_oauth_token when GitHub OAuth token is missing", %{task_id: task_id} do
      scope_without_token = user_scope_fixture()

      put_sandbox_mvp_config(
        image: @default_vm_image,
        repo_url: "https://github.com/frontman-ai/frontman.git"
      )

      assert {:error, :no_github_oauth_token} = SandboxInputs.build(scope_without_token, task_id)
    end
  end

  defp put_sandbox_mvp_config(overrides) do
    config =
      [
        enabled: true,
        image: @default_vm_image,
        repo_url: "https://github.com/frontman-ai/frontman.git",
        repo_ref: "main"
      ]
      |> Keyword.merge(overrides)

    Application.put_env(:frontman_server, :sandbox_mvp, config)
  end
end
