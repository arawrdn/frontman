defmodule FrontmanServerWeb.TaskChannelSandboxProvisioningTest do
  use FrontmanServerWeb.ChannelCase, async: false

  alias FrontmanServer.Providers
  alias FrontmanServer.Sandbox.EnvironmentSpec
  alias FrontmanServer.Test.Support.RepoAnalyses.StaticGitHubClient

  @moduletag :capture_log

  defmodule StuckProvisionProvider do
    @behaviour FrontmanServer.Sandbox.Provider

    @impl true
    def create(%EnvironmentSpec{} = spec, _opts) do
      {:ok, "stuck-#{spec.name}-#{System.unique_integer([:positive])}"}
    end

    @impl true
    def exec(_ref, _command, _args, _opts), do: {:error, :not_ready}

    @impl true
    def metrics(_ref), do: {:ok, %{running: false}}

    @impl true
    def stop(_ref), do: :ok

    @impl true
    def start(_ref), do: :ok

    @impl true
    def destroy(_ref), do: :ok
  end

  setup %{scope: scope} do
    original_sandbox_config = Application.fetch_env!(:frontman_server, :sandbox)

    sandbox_config =
      original_sandbox_config
      |> Keyword.put(:provider, StuckProvisionProvider)
      |> Keyword.update!(:bootstrap, fn bootstrap ->
        bootstrap
        |> Keyword.put(:wait_timeout_ms, 400)
        |> Keyword.put(:poll_interval_ms, 20)
      end)

    Application.put_env(:frontman_server, :sandbox, sandbox_config)

    {:ok, _oauth_token} =
      Providers.upsert_oauth_token(scope, "github", "channel-sandbox-github-token", nil, nil)

    on_exit(fn ->
      Application.put_env(:frontman_server, :sandbox, original_sandbox_config)

      DynamicSupervisor.which_children(FrontmanServer.Sandbox.DynamicSupervisor)
      |> Enum.each(fn
        {_, pid, _, _} when is_pid(pid) -> Process.exit(pid, :kill)
        _ -> :ok
      end)
    end)

    :ok
  end

  test "channel remains responsive while sandbox provisioning is pending", %{scope: scope} do
    {socket, _task_id} =
      join_task_channel(scope, repo_analyses_github_client: StaticGitHubClient)

    complete_mcp_handshake(socket)

    push(socket, "acp:message", build_prompt_request(id: 1, text: "Start"))

    ref =
      push(
        socket,
        "acp:message",
        build_acp_request("unknown/method", 2, %{})
      )

    assert_reply(ref, :ok, %{"acp:message" => %{"id" => 2, "error" => %{"code" => -32_601}}}, 150)

    assert_push(
      "acp:message",
      %{
        "params" => %{
          "update" => %{"sessionUpdate" => "error", "message" => ":sandbox_provisioning_timeout"}
        }
      },
      2_000
    )
  end
end
