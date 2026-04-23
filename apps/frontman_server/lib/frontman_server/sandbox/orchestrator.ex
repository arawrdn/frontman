defmodule FrontmanServer.Sandbox.Orchestrator do
  @moduledoc """
  Per-sandbox lifecycle GenServer.

  Manages a single sandbox VM through its lifecycle:
  provisioning → running → stopped/error. Polls the provider
  for health via heartbeat and delegates blocking exec calls
  to Task.Supervisor so the GenServer stays responsive.

  Started under Sandbox.DynamicSupervisor, registered in
  Sandbox.Registry by sandbox_id.
  """

  use GenServer, restart: :temporary

  require Logger

  alias FrontmanServer.Repo
  alias FrontmanServer.Sandbox.EnvironmentSpec
  alias FrontmanServer.Sandbox.SandboxSchema

  @default_heartbeat_interval_ms 30_000
  @default_provision_timeout_ms 300_000
  @default_exec_call_timeout_ms 120_000
  @exec_call_timeout_buffer_ms 5_000
  @sandbox_env_repo_url_key "FRONTMAN_SANDBOX_REPO_URL"
  @sandbox_env_repo_ref_key "FRONTMAN_SANDBOX_REPO_REF"
  @env_var_name_regex ~r/^[A-Za-z_][A-Za-z0-9_]*$/

  defstruct [
    :sandbox_id,
    :provider_ref,
    :status,
    :heartbeat_ref,
    :provision_timer_ref,
    :provider,
    :heartbeat_interval_ms,
    :provision_timeout_ms,
    :environment_spec,
    :task_supervisor,
    :setup_task_ref,
    :bootstrap_config
  ]

  @type orchestrator_status :: :provisioning | :running

  @type t :: %__MODULE__{
          sandbox_id: String.t(),
          provider_ref: String.t() | nil,
          status: orchestrator_status(),
          heartbeat_ref: reference() | nil,
          provision_timer_ref: reference() | nil,
          provider: module(),
          heartbeat_interval_ms: pos_integer(),
          provision_timeout_ms: pos_integer(),
          environment_spec: EnvironmentSpec.t() | nil,
          task_supervisor: term(),
          setup_task_ref: reference() | nil,
          bootstrap_config: map()
        }

  @type callback_reply ::
          {:reply, term(), t()}
          | {:noreply, t()}
          | {:stop, :normal, term(), t()}

  @type callback_noreply ::
          {:noreply, t()}
          | {:stop, :normal, t()}

  # --- Client API ---

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    sandbox_id = Keyword.fetch!(opts, :sandbox_id)

    GenServer.start_link(__MODULE__, opts,
      name: {:via, Registry, {FrontmanServer.Sandbox.Registry, sandbox_id}}
    )
  end

  @spec exec(String.t(), String.t(), [String.t()], keyword()) ::
          {:ok, map()} | {:error, term()}
  def exec(sandbox_id, command, args, opts \\ [])
      when is_binary(sandbox_id) and is_binary(command) and is_list(args) and is_list(opts) do
    call_timeout = exec_call_timeout(opts)

    case safe_call(sandbox_id, {:exec, command, args, opts}, call_timeout) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec stop(String.t()) :: :ok | {:error, term()}
  def stop(sandbox_id) when is_binary(sandbox_id) do
    case safe_call(sandbox_id, :stop) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec destroy(String.t()) :: :ok | {:error, term()}
  def destroy(sandbox_id) when is_binary(sandbox_id) do
    case safe_call(sandbox_id, :destroy) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @spec status(String.t()) :: {:ok, atom()} | {:error, :not_found | :timeout | term()}
  def status(sandbox_id) when is_binary(sandbox_id) do
    case safe_call(sandbox_id, :status) do
      {:ok, result} -> result
      {:error, :not_found} -> {:error, :not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  defp via(sandbox_id) when is_binary(sandbox_id) do
    {:via, Registry, {FrontmanServer.Sandbox.Registry, sandbox_id}}
  end

  # --- Server Callbacks ---

  @spec init(keyword()) :: {:ok, t(), {:continue, :provision}} | {:stop, :normal}
  @impl true
  def init(opts) when is_list(opts) do
    sandbox_id = Keyword.fetch!(opts, :sandbox_id)
    provider = Keyword.get(opts, :provider, default_provider())
    task_supervisor = Keyword.get(opts, :task_supervisor, FrontmanServer.Sandbox.TaskSupervisor)

    heartbeat_interval_ms =
      Keyword.get(opts, :heartbeat_interval_ms, @default_heartbeat_interval_ms)

    provision_timeout_ms =
      Keyword.get(opts, :provision_timeout_ms, @default_provision_timeout_ms)

    sandbox = Repo.get!(SandboxSchema, sandbox_id)

    state = %__MODULE__{
      sandbox_id: sandbox_id,
      provider: provider,
      status: :provisioning,
      heartbeat_interval_ms: heartbeat_interval_ms,
      provision_timeout_ms: provision_timeout_ms,
      task_supervisor: task_supervisor,
      bootstrap_config: %{}
    }

    case EnvironmentSpec.from_map(sandbox.env_spec) do
      {:ok, environment_spec} ->
        {:ok,
         %{
           state
           | environment_spec: environment_spec,
             bootstrap_config: sandbox_bootstrap_config(environment_spec)
         }, {:continue, :provision}}

      {:error, reason} ->
        Logger.error("[Orchestrator] invalid env_spec for #{sandbox_id}: #{inspect(reason)}")

        persist_status(sandbox_id, :error)
        {:stop, :normal}
    end
  end

  @spec handle_continue(:provision, t()) :: callback_noreply()
  @impl true
  def handle_continue(:provision, state) do
    with {:ok, routing} <- build_port_routing(state.environment_spec),
         {:ok, provider_ref} <-
           state.provider.create(state.environment_spec, port_forwards: routing.port_forwards) do
      sandbox = Repo.get!(SandboxSchema, state.sandbox_id)

      sandbox
      |> Ecto.Changeset.change(
        provider_ref: provider_ref,
        port_map: routing.port_map,
        preview_url: preview_url(state.sandbox_id)
      )
      |> Repo.update!()

      provision_timer_ref =
        Process.send_after(self(), :provision_timeout, state.provision_timeout_ms)

      heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)

      case start_setup_task(state, provider_ref) do
        {:ok, setup_task_ref} ->
          {:noreply,
           %{
             state
             | provider_ref: provider_ref,
               heartbeat_ref: heartbeat_ref,
               provision_timer_ref: provision_timer_ref,
               setup_task_ref: setup_task_ref
           }}

        {:error, reason} ->
          Logger.error(
            "[Orchestrator] failed to start setup task for #{state.sandbox_id}: " <>
              inspect(reason)
          )

          persist_status(state.sandbox_id, :error)
          {:stop, :normal, state}
      end
    else
      {:error, reason} ->
        Logger.error(
          "[Orchestrator] provider.create failed for #{state.sandbox_id}: #{inspect(reason)}"
        )

        persist_status(state.sandbox_id, :error)
        {:stop, :normal, state}
    end
  end

  @spec handle_call(term(), GenServer.from(), t()) :: callback_reply()
  @impl true
  def handle_call({:exec, command, args, opts}, from, %{status: :running} = state) do
    case start_exec_task(state.task_supervisor, fn ->
           result = state.provider.exec(state.provider_ref, command, args, opts)
           GenServer.reply(from, result)
         end) do
      {:ok, _pid} ->
        touch_last_active_and_log(state.sandbox_id)
        {:noreply, state}

      {:error, reason} ->
        {:reply, {:error, {:task_start_failed, reason}}, state}
    end
  end

  def handle_call({:exec, _, _, _}, _from, %{status: :provisioning} = state) do
    {:reply, {:error, :not_ready}, state}
  end

  def handle_call(:stop, _from, state) do
    case state.provider.stop(state.provider_ref) do
      :ok ->
        case persist_status(state.sandbox_id, :stopped) do
          :ok ->
            {:stop, :normal, :ok, state}

          {:error, reason} ->
            {:stop, :normal, {:error, {:status_persist_failed, reason}}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:destroy, _from, state) do
    case state.provider.destroy(state.provider_ref) do
      :ok ->
        case delete_sandbox_record(state.sandbox_id) do
          :ok ->
            {:stop, :normal, :ok, state}

          {:error, reason} ->
            {:stop, :normal, {:error, {:delete_failed, reason}}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call(:status, _from, state) do
    {:reply, {:ok, state.status}, state}
  end

  @spec handle_info(term(), t()) :: callback_noreply()
  @impl true
  def handle_info({ref, :ok}, %{setup_task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])
    transition_to_running_or_reschedule(%{state | setup_task_ref: nil})
  end

  def handle_info({ref, {:error, reason}}, %{setup_task_ref: ref} = state) do
    Process.demonitor(ref, [:flush])

    Logger.error(
      "[Orchestrator] setup sequence failed for #{state.sandbox_id}: #{inspect(reason)}"
    )

    persist_status(state.sandbox_id, :error)
    {:stop, :normal, %{state | setup_task_ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, :normal}, %{setup_task_ref: ref} = state) do
    {:noreply, %{state | setup_task_ref: nil}}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, %{setup_task_ref: ref} = state) do
    Logger.error("[Orchestrator] setup task crashed for #{state.sandbox_id}: #{inspect(reason)}")

    persist_status(state.sandbox_id, :error)
    {:stop, :normal, %{state | setup_task_ref: nil}}
  end

  def handle_info({ref, :ok}, state) when is_reference(ref) do
    Logger.debug("[Orchestrator] ignoring unrelated task success for ref=#{inspect(ref)}")
    {:noreply, state}
  end

  def handle_info({ref, {:error, reason}}, state) when is_reference(ref) do
    Logger.warning(
      "[Orchestrator] ignoring unrelated task error for ref=#{inspect(ref)}: #{inspect(reason)}"
    )

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _pid, reason}, state) when is_reference(ref) do
    Logger.debug(
      "[Orchestrator] ignoring unrelated task DOWN for ref=#{inspect(ref)}: #{inspect(reason)}"
    )

    {:noreply, state}
  end

  def handle_info(:heartbeat, %{status: :provisioning} = state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        transition_to_running_or_reschedule(state)

      {:ok, %{running: false}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:error, reason} ->
        Logger.warning(
          "[Orchestrator] heartbeat metrics failed for #{state.sandbox_id}: #{inspect(reason)}"
        )

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:ok, metrics} ->
        Logger.warning(
          "[Orchestrator] invalid heartbeat metrics for #{state.sandbox_id}: " <>
            inspect(metrics)
        )

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  def handle_info(:heartbeat, %{status: :running} = state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:ok, %{running: false}} ->
        Logger.error("[Orchestrator] VM crashed for #{state.sandbox_id}")
        persist_status(state.sandbox_id, :error)
        {:stop, :normal, state}

      {:error, reason} ->
        Logger.warning(
          "[Orchestrator] heartbeat metrics failed for #{state.sandbox_id}: #{inspect(reason)}"
        )

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:ok, metrics} ->
        Logger.warning(
          "[Orchestrator] invalid heartbeat metrics for #{state.sandbox_id}: " <>
            inspect(metrics)
        )

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  def handle_info(:provision_timeout, %{status: :provisioning} = state) do
    Logger.error("[Orchestrator] provisioning timed out for #{state.sandbox_id}")
    persist_status(state.sandbox_id, :error)
    {:stop, :normal, state}
  end

  def handle_info(:provision_timeout, state) do
    {:noreply, state}
  end

  def handle_info(message, state) do
    Logger.warning("[Orchestrator] unexpected message: #{inspect(message)}")
    {:noreply, state}
  end

  @spec terminate(term(), t()) :: :ok
  @impl true
  def terminate(reason, state) do
    if state.heartbeat_ref, do: Process.cancel_timer(state.heartbeat_ref)
    if state.provision_timer_ref, do: Process.cancel_timer(state.provision_timer_ref)
    if state.setup_task_ref, do: Process.demonitor(state.setup_task_ref, [:flush])

    Logger.info(
      "[Orchestrator] terminating #{state.sandbox_id} " <>
        "(status=#{state.status}, reason=#{inspect(reason)})"
    )

    :ok
  end

  # --- Private Helpers ---

  defp start_setup_task(state, provider_ref) do
    task =
      Task.Supervisor.async_nolink(state.task_supervisor, fn ->
        run_setup_sequence(state.provider, provider_ref, state.bootstrap_config)
      end)

    {:ok, task.ref}
  catch
    :exit, reason -> {:error, reason}
  end

  defp transition_to_running_or_reschedule(%{setup_task_ref: setup_task_ref} = state)
       when not is_nil(setup_task_ref) do
    heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
    {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
  end

  defp transition_to_running_or_reschedule(state) do
    case state.provider.metrics(state.provider_ref) do
      {:ok, %{running: true}} ->
        if state.provision_timer_ref, do: Process.cancel_timer(state.provision_timer_ref)

        case persist_status(state.sandbox_id, :running) do
          :ok ->
            heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)

            {:noreply,
             %{state | status: :running, provision_timer_ref: nil, heartbeat_ref: heartbeat_ref}}

          {:error, _reason} ->
            persist_status(state.sandbox_id, :error)
            {:stop, :normal, state}
        end

      {:ok, %{running: false}} ->
        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:error, reason} ->
        Logger.warning(
          "[Orchestrator] transition metrics failed for #{state.sandbox_id}: #{inspect(reason)}"
        )

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}

      {:ok, metrics} ->
        Logger.warning(
          "[Orchestrator] invalid transition metrics for #{state.sandbox_id}: " <>
            inspect(metrics)
        )

        heartbeat_ref = schedule_heartbeat(state.heartbeat_interval_ms)
        {:noreply, %{state | heartbeat_ref: heartbeat_ref}}
    end
  end

  defp run_setup_sequence(provider, provider_ref, config) do
    step_timeout_ms = Map.fetch!(config, :step_timeout_ms)

    with :ok <- wait_for_vm_running(provider, provider_ref, step_timeout_ms),
         :ok <- sync_repo(provider, provider_ref, config, step_timeout_ms),
         :ok <-
           run_post_create_command(
             provider,
             provider_ref,
             config.post_create_workdir,
             config,
             step_timeout_ms
           ),
         :ok <-
           run_post_start_command(
             provider,
             provider_ref,
             config.post_start_workdir,
             config,
             step_timeout_ms
           ) do
      wait_for_health(provider, provider_ref, config, step_timeout_ms)
    end
  end

  defp wait_for_vm_running(provider, provider_ref, timeout_ms) do
    deadline_ms = System.monotonic_time(:millisecond) + timeout_ms
    wait_for_vm_running_until(provider, provider_ref, deadline_ms)
  end

  defp wait_for_vm_running_until(provider, provider_ref, deadline_ms) do
    case provider.metrics(provider_ref) do
      {:ok, %{running: true}} ->
        :ok

      _other ->
        now_ms = System.monotonic_time(:millisecond)

        case now_ms >= deadline_ms do
          true ->
            {:error, {:wait_for_vm_running, :timeout}}

          false ->
            Process.sleep(1_000)
            wait_for_vm_running_until(provider, provider_ref, deadline_ms)
        end
    end
  end

  defp sync_repo(provider, provider_ref, config, timeout_ms) do
    escaped_project_root = shell_escape(config.project_root)
    escaped_git_dir = shell_escape(Path.join(config.project_root, ".git"))
    escaped_repo_url = shell_escape(config.repo_url)
    escaped_repo_ref = shell_escape(config.repo_ref)

    script =
      "if [ -d " <>
        escaped_git_dir <>
        " ]; then " <>
        "git -C " <>
        escaped_project_root <>
        " remote set-url origin " <>
        escaped_repo_url <>
        " >/dev/null 2>&1 || git -C " <>
        escaped_project_root <>
        " remote add origin " <>
        escaped_repo_url <>
        " >/dev/null 2>&1; " <>
        "git -C " <>
        escaped_project_root <>
        " fetch --depth 1 origin " <>
        escaped_repo_ref <>
        " && git -C " <>
        escaped_project_root <>
        " checkout -f FETCH_HEAD; " <>
        "else " <>
        "rm -rf " <>
        escaped_project_root <>
        " && git init " <>
        escaped_project_root <>
        " && git -C " <>
        escaped_project_root <>
        " remote add origin " <>
        escaped_repo_url <>
        " && git -C " <>
        escaped_project_root <>
        " fetch --depth 1 origin " <>
        escaped_repo_ref <>
        " && git -C " <>
        escaped_project_root <>
        " checkout -f FETCH_HEAD; " <>
        "fi"

    run_setup_step(provider, provider_ref, :sync_repo, script, timeout_ms)
  end

  defp run_post_create_command(provider, provider_ref, workdir, config, timeout_ms) do
    script =
      ("cd " <> shell_escape(workdir) <> " && " <> config.post_create_command)
      |> script_with_remote_env(config.remote_env)

    run_setup_step(provider, provider_ref, :install_dependencies, script, timeout_ms)
  end

  defp run_post_start_command(provider, provider_ref, workdir, config, timeout_ms) do
    stop_existing_process_script =
      "if [ -f /tmp/frontman-app.pid ]; then " <>
        "kill $(cat /tmp/frontman-app.pid) >/dev/null 2>&1 || true; " <>
        "fi"

    script =
      ("cd " <>
         shell_escape(workdir) <>
         " && " <>
         stop_existing_process_script <>
         " && nohup " <>
         config.post_start_command <>
         " >/tmp/frontman-app.log 2>&1 & echo $! > /tmp/frontman-app.pid")
      |> script_with_remote_env(config.remote_env)

    run_setup_step(provider, provider_ref, :start_application, script, timeout_ms)
  end

  defp wait_for_health(provider, provider_ref, config, timeout_ms) do
    health_url =
      "http://127.0.0.1:" <> Integer.to_string(config.app_port) <> to_string(config.health_path)

    script =
      "for i in $(seq 1 60); do " <>
        "curl -fsS " <>
        shell_escape(health_url) <>
        " >/dev/null 2>&1 && exit 0; " <>
        "sleep 2; " <>
        "done; " <>
        "echo healthcheck_failed; exit 1"

    run_setup_step(provider, provider_ref, :wait_for_health, script, timeout_ms)
  end

  defp run_setup_step(provider, provider_ref, step, script, timeout_ms) do
    case provider.exec(provider_ref, "bash", ["-lc", script], timeout_ms: timeout_ms) do
      {:ok, %{exit_code: 0}} ->
        :ok

      {:ok, %{exit_code: exit_code, stdout: stdout, stderr: stderr}} ->
        command_result = %{
          exit_code: exit_code,
          stdout: String.trim(stdout),
          stderr: String.trim(stderr)
        }

        {:error, {step, command_result}}

      {:error, reason} ->
        {:error, {step, reason}}
    end
  end

  defp sandbox_bootstrap_config(environment_spec) do
    config =
      Application.fetch_env!(:frontman_server, :sandbox)
      |> Keyword.fetch!(:bootstrap)

    env = environment_spec_env(environment_spec)
    devcontainer = environment_spec.devcontainer
    project_root = Keyword.fetch!(config, :project_root)
    app_dir = Keyword.fetch!(config, :app_dir)
    app_root = Path.join(project_root, app_dir)

    default_install_command =
      normalize_command(Keyword.fetch!(config, :install_command))

    default_start_command =
      normalize_command(Keyword.fetch!(config, :start_command))

    default_app_port = Keyword.fetch!(config, :app_port)

    repo_url = required_env_override!(env, @sandbox_env_repo_url_key)
    repo_ref = required_env_override!(env, @sandbox_env_repo_ref_key)

    {post_create_command, post_create_workdir} =
      resolve_setup_command_and_workdir(
        devcontainer,
        "postCreateCommand",
        :postCreateCommand,
        default_install_command,
        project_root,
        app_root
      )

    {post_start_command, post_start_workdir} =
      resolve_setup_command_and_workdir(
        devcontainer,
        "postStartCommand",
        :postStartCommand,
        default_start_command,
        project_root,
        app_root
      )

    %{
      repo_url: repo_url,
      repo_ref: repo_ref,
      project_root: project_root,
      app_dir: app_dir,
      post_create_workdir: post_create_workdir,
      post_create_command: post_create_command,
      post_start_workdir: post_start_workdir,
      post_start_command: post_start_command,
      remote_env: devcontainer_remote_env(devcontainer),
      app_port: devcontainer_app_port(devcontainer, default_app_port),
      health_path: Keyword.fetch!(config, :health_path),
      step_timeout_ms: Keyword.fetch!(config, :step_timeout_ms)
    }
  end

  defp normalize_command(command) when is_binary(command) do
    trimmed_command = String.trim(command)

    case trimmed_command do
      "" -> raise "Sandbox command config must be a non-empty string"
      _ -> trimmed_command
    end
  end

  defp normalize_command(_command), do: raise("Sandbox command config must be a string")

  defp resolve_setup_command_and_workdir(
         devcontainer,
         key,
         atom_key,
         fallback,
         project_root,
         app_root
       )
       when is_map(devcontainer) and is_binary(key) and is_atom(atom_key) and is_binary(fallback) and
              is_binary(project_root) and is_binary(app_root) do
    command = Map.get_lazy(devcontainer, key, fn -> Map.get(devcontainer, atom_key) end)

    case normalize_devcontainer_command(command) do
      nil -> {fallback, app_root}
      normalized_command -> {normalized_command, project_root}
    end
  end

  defp resolve_setup_command_and_workdir(
         _devcontainer,
         _key,
         _atom_key,
         fallback,
         _project_root,
         app_root
       ),
       do: {fallback, app_root}

  defp normalize_devcontainer_command(command) when is_binary(command) do
    trimmed_command = String.trim(command)

    case trimmed_command do
      "" -> nil
      _ -> trimmed_command
    end
  end

  defp normalize_devcontainer_command(command) when is_list(command) do
    case command do
      [] ->
        nil

      _ ->
        case Enum.all?(command, &is_binary/1) do
          true ->
            Enum.map_join(command, " ", &shell_escape/1)

          false ->
            nil
        end
    end
  end

  defp normalize_devcontainer_command(_command), do: nil

  defp devcontainer_remote_env(devcontainer) when is_map(devcontainer) do
    remote_env =
      Map.get_lazy(devcontainer, "remoteEnv", fn ->
        Map.get(devcontainer, :remoteEnv)
      end)

    case remote_env do
      remote_env when is_map(remote_env) ->
        Enum.reduce(remote_env, %{}, &put_valid_remote_env_entry/2)

      _ ->
        %{}
    end
  end

  defp devcontainer_remote_env(_devcontainer), do: %{}

  defp put_valid_remote_env_entry({key, value}, acc) do
    case valid_remote_env_entry?(key, value) do
      true -> Map.put(acc, key, value)
      false -> acc
    end
  end

  defp put_valid_remote_env_entry(_entry, acc), do: acc

  defp valid_remote_env_entry?(key, value)
       when is_binary(key) and is_binary(value) do
    Regex.match?(@env_var_name_regex, key)
  end

  defp valid_remote_env_entry?(_key, _value), do: false

  defp devcontainer_app_port(devcontainer, default_app_port)
       when is_map(devcontainer) and is_integer(default_app_port) do
    case devcontainer_forward_ports(devcontainer) do
      [port | _] -> port
      [] -> default_app_port
    end
  end

  defp devcontainer_app_port(_devcontainer, default_app_port), do: default_app_port

  defp environment_spec_env(%EnvironmentSpec{env: env}) when is_map(env), do: env
  defp environment_spec_env(_), do: %{}

  defp required_env_override!(env, key) do
    case Map.get(env, key) do
      value when is_binary(value) and byte_size(value) > 0 -> value
      _ -> raise("Environment spec is missing required sandbox key: #{key}")
    end
  end

  defp script_with_remote_env(script, remote_env) when is_binary(script) and is_map(remote_env) do
    case remote_env_exports(remote_env) do
      "" -> script
      exports -> exports <> " && " <> script
    end
  end

  defp remote_env_exports(remote_env) when map_size(remote_env) == 0, do: ""

  defp remote_env_exports(remote_env) do
    remote_env
    |> Enum.sort_by(fn {key, _value} -> key end)
    |> Enum.map_join(" && ", fn {key, value} -> "export " <> key <> "=" <> shell_escape(value) end)
  end

  defp shell_escape(value) when is_binary(value) do
    "'" <> String.replace(value, "'", "'\"'\"'") <> "'"
  end

  defp schedule_heartbeat(interval_ms) do
    Process.send_after(self(), :heartbeat, interval_ms)
  end

  defp update_db_status(sandbox_id, new_status) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil ->
        Logger.warning("[Orchestrator] sandbox not found in DB: #{sandbox_id}")
        {:error, :not_found}

      sandbox ->
        sandbox
        |> SandboxSchema.status_changeset(new_status)
        |> Repo.update()
    end
  end

  defp persist_status(sandbox_id, new_status) do
    case update_db_status(sandbox_id, new_status) do
      {:ok, _sandbox} ->
        :ok

      {:error, reason} ->
        Logger.error(
          "[Orchestrator] failed to persist #{new_status} status for #{sandbox_id}: " <>
            inspect(reason)
        )

        {:error, reason}
    end
  end

  defp delete_sandbox_record(sandbox_id) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil ->
        :ok

      sandbox ->
        case Repo.delete(sandbox) do
          {:ok, _sandbox} ->
            :ok

          {:error, reason} ->
            Logger.error(
              "[Orchestrator] failed to delete sandbox #{sandbox_id}: #{inspect(reason)}"
            )

            {:error, reason}
        end
    end
  end

  defp touch_last_active_and_log(sandbox_id) do
    case touch_last_active(sandbox_id) do
      :ok ->
        :ok

      {:error, :not_found} ->
        Logger.debug("[Orchestrator] sandbox missing when touching activity: #{sandbox_id}")
        :ok

      {:error, reason} ->
        Logger.warning(
          "[Orchestrator] failed to touch last active for #{sandbox_id}: #{inspect(reason)}"
        )

        :ok
    end
  end

  defp touch_last_active(sandbox_id) do
    case Repo.get(SandboxSchema, sandbox_id) do
      nil ->
        {:error, :not_found}

      sandbox ->
        case sandbox |> SandboxSchema.touch_changeset() |> Repo.update() do
          {:ok, _sandbox} ->
            :ok

          {:error, reason} ->
            {:error, reason}
        end
    end
  end

  defp default_provider do
    Application.fetch_env!(:frontman_server, :sandbox)
    |> Keyword.fetch!(:provider)
  end

  defp build_port_routing(environment_spec) do
    guest_ports =
      environment_spec.devcontainer
      |> devcontainer_forward_ports()
      |> default_forward_ports()

    port_forwards =
      Enum.map(guest_ports, fn guest_port ->
        %{guest_port: guest_port, host_port: reserve_host_port()}
      end)

    case port_forwards do
      [%{host_port: preview_host_port} | _] ->
        port_map =
          Enum.reduce(port_forwards, %{}, fn %{guest_port: guest_port, host_port: host_port},
                                             acc ->
            Map.put(acc, Integer.to_string(guest_port), host_port)
          end)
          |> Map.put("web_preview_host_port", preview_host_port)

        {:ok, %{port_forwards: port_forwards, port_map: port_map}}

      [] ->
        {:error, :missing_forward_ports}
    end
  end

  defp devcontainer_forward_ports(devcontainer) when is_map(devcontainer) do
    forward_ports =
      Map.get_lazy(devcontainer, "forwardPorts", fn ->
        Map.get(devcontainer, :forwardPorts, [])
      end)

    case forward_ports do
      forward_ports when is_list(forward_ports) ->
        forward_ports
        |> Enum.flat_map(&normalize_forward_port/1)
        |> Enum.uniq()

      _ ->
        []
    end
  end

  defp devcontainer_forward_ports(_), do: []

  defp normalize_forward_port(port) when is_integer(port) and port > 0 and port <= 65_535,
    do: [port]

  defp normalize_forward_port(port) when is_binary(port) do
    case Integer.parse(port) do
      {value, ""} when value > 0 and value <= 65_535 -> [value]
      _ -> []
    end
  end

  defp normalize_forward_port(_), do: []

  defp default_forward_ports([]), do: [3000]
  defp default_forward_ports(ports), do: ports

  defp reserve_host_port do
    {:ok, socket} = :gen_tcp.listen(0, [:binary, active: false, ip: {127, 0, 0, 1}])
    {:ok, port} = :inet.port(socket)
    :ok = :gen_tcp.close(socket)
    port
  end

  defp preview_url(sandbox_id) do
    preview_config =
      Application.fetch_env!(:frontman_server, :sandbox)
      |> Keyword.fetch!(:preview_proxy)

    preview_base_host = Keyword.fetch!(preview_config, :preview_base_host)
    preview_scheme = Keyword.fetch!(preview_config, :preview_scheme)

    case {preview_base_host, preview_scheme} do
      {base_host, scheme}
      when is_binary(base_host) and byte_size(base_host) > 0 and is_binary(scheme) and
             byte_size(scheme) > 0 ->
        "#{scheme}://#{sandbox_id}.#{base_host}"

      _ ->
        raise "Config :frontman_server, :sandbox[:preview_proxy] must include non-empty :preview_base_host and :preview_scheme"
    end
  end

  defp exec_call_timeout(opts) do
    case Keyword.get(opts, :timeout_ms, @default_exec_call_timeout_ms) do
      :infinity ->
        :infinity

      timeout_ms when is_integer(timeout_ms) and timeout_ms > 0 ->
        timeout_ms + @exec_call_timeout_buffer_ms

      _ ->
        @default_exec_call_timeout_ms
    end
  end

  defp safe_call(sandbox_id, message, timeout \\ 5_000) do
    {:ok, GenServer.call(via(sandbox_id), message, timeout)}
  catch
    :exit, {:noproc, _} -> {:error, :not_found}
    :exit, :noproc -> {:error, :not_found}
    :exit, {:timeout, _} -> {:error, :timeout}
    :exit, {:normal, _} -> {:error, :server_terminated}
  end

  defp start_exec_task(task_supervisor, fun) do
    Task.Supervisor.start_child(task_supervisor, fun)
  catch
    :exit, reason -> {:error, reason}
  end
end
