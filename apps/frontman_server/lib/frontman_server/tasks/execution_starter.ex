defmodule FrontmanServer.Tasks.ExecutionStarter do
  @moduledoc false

  use GenServer, restart: :temporary

  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks

  @registry FrontmanServer.Tasks.ExecutionStartRegistry
  @dynamic_supervisor FrontmanServer.Tasks.ExecutionStartDynamicSupervisor

  @typep state :: %{
           scope: Scope.t(),
           task_id: String.t(),
           tools: list(),
           opts: keyword()
         }

  @spec start_or_join(Scope.t(), String.t(), list(), keyword()) :: :ok | :already_running
  def start_or_join(%Scope{} = scope, task_id, tools, opts) do
    child = {__MODULE__, [scope: scope, task_id: task_id, tools: tools, opts: opts]}

    case DynamicSupervisor.start_child(@dynamic_supervisor, child) do
      {:ok, _pid} ->
        :ok

      {:error, {:already_started, _pid}} ->
        :already_running

      other ->
        raise "Failed to start execution starter: #{inspect(other)}"
    end
  end

  @spec running?(String.t()) :: boolean()
  def running?(task_id) when is_binary(task_id) do
    case Registry.lookup(@registry, task_id) do
      [{_pid, _}] -> true
      [] -> false
    end
  end

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts) when is_list(opts) do
    task_id = Keyword.fetch!(opts, :task_id)
    GenServer.start_link(__MODULE__, opts, name: via(task_id))
  end

  @impl true
  @spec init(keyword()) :: {:ok, state(), {:continue, :start_execution}}
  def init(opts) when is_list(opts) do
    state = %{
      scope: Keyword.fetch!(opts, :scope),
      task_id: Keyword.fetch!(opts, :task_id),
      tools: Keyword.fetch!(opts, :tools),
      opts: Keyword.fetch!(opts, :opts)
    }

    {:ok, state, {:continue, :start_execution}}
  end

  @impl true
  @spec handle_continue(:start_execution, state()) :: {:stop, :normal, state()}
  def handle_continue(:start_execution, state) do
    Tasks.start_execution_sync(state.scope, state.task_id, state.tools, state.opts)
    {:stop, :normal, state}
  end

  defp via(task_id) when is_binary(task_id) do
    {:via, Registry, {@registry, task_id}}
  end
end
