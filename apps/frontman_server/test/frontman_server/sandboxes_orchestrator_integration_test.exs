defmodule FrontmanServer.SandboxesOrchestratorIntegrationTest do
  @moduledoc """
  Higher-fidelity integration tests for Sandboxes + Orchestrator lifecycle.

  Uses a concrete test provider module instead of Mox expectations to keep
  behavior close to production orchestration.
  """

  use FrontmanServer.DataCase

  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Sandboxes

  alias FrontmanServer.Sandbox.SandboxSchema
  alias FrontmanServer.Sandboxes
  alias FrontmanServer.Test.Support.Sandbox.IntegrationProvider
  alias FrontmanServer.Test.Support.Sandbox.ScriptCaptureProvider

  setup do
    scope = user_scope_fixture()
    task = task_with_project_fixture(scope)

    IntegrationProvider.reset!()
    ScriptCaptureProvider.reset!()

    on_exit(fn ->
      IntegrationProvider.reset!()
      ScriptCaptureProvider.reset!()

      DynamicSupervisor.which_children(FrontmanServer.Sandbox.DynamicSupervisor)
      |> Enum.each(fn {_, pid, _, _} ->
        if is_pid(pid) and Process.alive?(pid) do
          Process.exit(pid, :kill)
        end
      end)
    end)

    %{scope: scope, task: task}
  end

  test "rebuilds persisted env_spec into EnvironmentSpec before provider.create", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert {:ok, %{exit_code: 0, stdout: "ok\n"}} =
             Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])
  end

  test "sync_repo setup step supports immutable commit refs", %{scope: scope, task: task} do
    original_sandbox_config = Application.fetch_env!(:frontman_server, :sandbox)

    sandbox_config =
      Keyword.update!(original_sandbox_config, :bootstrap, fn bootstrap ->
        Keyword.put(bootstrap, :project_root, "/workspace/frontman")
      end)

    Application.put_env(:frontman_server, :sandbox, sandbox_config)

    on_exit(fn ->
      Application.put_env(:frontman_server, :sandbox, original_sandbox_config)
    end)

    commit_sha = String.duplicate("a", 40)

    env_spec =
      unique_env_spec(%{
        "FRONTMAN_SANDBOX_REPO_REF" => commit_sha,
        "FRONTMAN_SANDBOX_REPO_URL" => "https://github.com/frontman-ai/frontman.git"
      })
      |> Map.put("devcontainer", %{
        "postCreateCommand" => "bash .devcontainer/post-create.sh",
        "forwardPorts" => [3000]
      })

    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, env_spec,
               task_id: task.id,
               provider: ScriptCaptureProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    provider_ref = Repo.get!(SandboxSchema, sandbox.id).provider_ref

    scripts =
      provider_ref
      |> ScriptCaptureProvider.exec_calls()
      |> Enum.flat_map(fn
        %{command: "bash", args: ["-lc", script]} -> [script]
        _ -> []
      end)

    assert Enum.any?(scripts, &String.contains?(&1, "fetch --depth 1 origin '#{commit_sha}'"))

    refute Enum.any?(scripts, fn script ->
             String.contains?(script, "clone --depth 1 --branch")
           end)

    assert Enum.any?(scripts, fn script ->
             String.contains?(
               script,
               "cd '/workspace/frontman' && bash .devcontainer/post-create.sh"
             )
           end)

    refute Enum.any?(scripts, &String.contains?(&1, "nohup "))
    refute Enum.any?(scripts, &String.contains?(&1, "healthcheck_failed"))
  end

  test "marks sandbox as error when provider.create fails", %{scope: scope, task: task} do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(%{"create_error" => "true"}),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :error
    end)
  end

  test "provisioning work runs asynchronously after init", %{scope: scope, task: task} do
    delayed_env_spec =
      unique_env_spec(%{
        "create_delay_ms" => "500"
      })

    started_at = System.monotonic_time(:millisecond)

    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, delayed_env_spec,
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    elapsed_ms = System.monotonic_time(:millisecond) - started_at
    assert elapsed_ms < 250

    assert_eventually(
      fn ->
        Repo.get!(SandboxSchema, sandbox.id).status == :running
      end,
      2_000
    )
  end

  test "returns task_start_failed when task supervisor is unavailable for exec", %{
    scope: scope,
    task: task
  } do
    task_supervisor = start_supervised!({Task.Supervisor, []})

    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               task_supervisor: task_supervisor,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    ref = Process.monitor(task_supervisor)
    :ok = Supervisor.stop(task_supervisor)
    assert_receive {:DOWN, ^ref, :process, ^task_supervisor, :normal}, 1_000

    assert {:error, {:task_start_failed, _reason}} =
             Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])
  end

  test "returns orchestrator_not_running when sandbox row exists but process is gone", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert :ok = Sandboxes.stop_sandbox(scope, sandbox.id)

    assert {:error, :orchestrator_not_running} =
             Sandboxes.exec(scope, sandbox.id, "echo", ["hello"])

    assert {:error, :orchestrator_not_running} = Sandboxes.stop_sandbox(scope, sandbox.id)
  end

  test "stop_sandbox routes stop through orchestrator and updates status", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert :ok = Sandboxes.stop_sandbox(scope, sandbox.id)
    assert Repo.get!(SandboxSchema, sandbox.id).status == :stopped
  end

  test "destroy_sandbox routes destroy through orchestrator and deletes row", %{
    scope: scope,
    task: task
  } do
    assert {:ok, sandbox} =
             Sandboxes.provision_and_start(scope, unique_env_spec(),
               task_id: task.id,
               provider: IntegrationProvider,
               heartbeat_interval_ms: 10,
               provision_timeout_ms: 5_000
             )

    assert_eventually(fn ->
      Repo.get!(SandboxSchema, sandbox.id).status == :running
    end)

    assert :ok = Sandboxes.destroy_sandbox(scope, sandbox.id)
    assert Repo.get(SandboxSchema, sandbox.id) == nil
  end

  defp unique_env_spec(env_overrides \\ %{}) do
    env_spec = valid_env_spec()
    existing_env = Map.get(env_spec, "env", %{})

    env_spec
    |> Map.put("name", "integration-sandbox-#{System.unique_integer([:positive])}")
    |> Map.put("env", Map.merge(existing_env, env_overrides))
  end

  defp assert_eventually(fun, timeout \\ 1_000, interval \\ 10) do
    deadline = System.monotonic_time(:millisecond) + timeout
    do_assert_eventually(fun, deadline, interval)
  end

  defp do_assert_eventually(fun, deadline, interval) do
    if fun.() do
      true
    else
      if System.monotonic_time(:millisecond) >= deadline do
        flunk("assert_eventually timed out")
      else
        Process.sleep(interval)
        do_assert_eventually(fun, deadline, interval)
      end
    end
  end
end
