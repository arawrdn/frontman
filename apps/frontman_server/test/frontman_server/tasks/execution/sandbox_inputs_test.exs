defmodule FrontmanServer.Tasks.Execution.SandboxInputsTest do
  use FrontmanServer.DataCase, async: false

  import FrontmanServer.Test.Fixtures.Accounts

  alias FrontmanServer.Providers
  alias FrontmanServer.Tasks.Execution.SandboxInputs
  alias FrontmanServer.Test.Support.RepoAnalyses.GitHubClientHelpers

  @default_vm_image "ghcr.io/frontman-ai/frontman-dev:stable"
  @default_repo_url "https://github.com/frontman-ai/frontman.git"

  setup do
    scope = user_scope_fixture()

    original_sandbox_config = Application.fetch_env!(:frontman_server, :sandbox)

    {:ok, _oauth_token} =
      Providers.upsert_oauth_token(scope, "github", "sandbox-inputs-github-token", nil, nil)

    GitHubClientHelpers.setup_static_client()

    on_exit(fn ->
      Application.put_env(:frontman_server, :sandbox, original_sandbox_config)
    end)

    %{scope: scope, task_id: Ecto.UUID.generate()}
  end

  describe "build/2" do
    test "uses configured VM image and keeps analyzed devcontainer raw", %{
      scope: scope,
      task_id: task_id
    } do
      put_sandbox_config(image: @default_vm_image)

      assert {:ok, env_spec} =
               SandboxInputs.build(scope, task_id)

      assert env_spec["image"] == @default_vm_image

      assert env_spec["devcontainer"]["image"] ==
               "mcr.microsoft.com/devcontainers/base:ubuntu-24.04"

      assert env_spec["env"]["FRONTMAN_SANDBOX_REPO_URL"] ==
               @default_repo_url

      assert env_spec["env"]["FRONTMAN_SANDBOX_REPO_REF"] == String.duplicate("a", 40)
      assert String.starts_with?(env_spec["name"], "task-")
    end

    test "returns invalid_sandbox_vm_image when sandbox image is blank", %{
      scope: scope,
      task_id: task_id
    } do
      put_sandbox_config(image: "   ")

      assert {:error, :invalid_sandbox_vm_image} =
               SandboxInputs.build(scope, task_id)
    end

    test "returns no_github_oauth_token when GitHub OAuth token is missing", %{task_id: task_id} do
      scope_without_token = user_scope_fixture()

      put_sandbox_config(image: @default_vm_image)

      assert {:error, :no_github_oauth_token} =
               SandboxInputs.build(scope_without_token, task_id)
    end
  end

  defp put_sandbox_config(overrides) do
    sandbox_config = Application.fetch_env!(:frontman_server, :sandbox)

    sandbox_config =
      Keyword.update!(sandbox_config, :bootstrap, fn bootstrap ->
        bootstrap
        |> Keyword.merge(image: @default_vm_image)
        |> Keyword.merge(overrides)
      end)

    Application.put_env(:frontman_server, :sandbox, sandbox_config)
  end
end
