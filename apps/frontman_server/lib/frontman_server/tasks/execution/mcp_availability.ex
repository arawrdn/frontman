defmodule FrontmanServer.Tasks.Execution.MCPAvailability do
  @moduledoc """
  Tracks MCP server availability per task and manages grace period timers.

  When the browser tab closes, the MCP server becomes unreachable and the
  agent cannot execute tools. This GenServer gives the connection a grace
  period to recover (tab reload, brief network drop) before cancelling the
  execution.
  """
  use GenServer

  require Logger

  @default_grace_period_ms :timer.minutes(1)

  # -- Public API --

  def start_link(opts) do
    {name, opts} = Keyword.pop(opts, :name)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Signal that the MCP server is available for the given task.
  Cancels any pending grace period timer.
  """
  @spec mcp_server_available(GenServer.server(), String.t()) :: :ok
  def mcp_server_available(server, task_id) do
    GenServer.cast(server, {:available, task_id})
  end

  @doc """
  Signal that the MCP server is no longer available for the given task.
  Starts the grace period timer. When it expires, `cancel_fn` is called.
  """
  @spec mcp_server_unavailable(GenServer.server(), String.t(), (-> any())) :: :ok
  def mcp_server_unavailable(server, task_id, cancel_fn) do
    GenServer.cast(server, {:unavailable, task_id, cancel_fn})
  end

  # -- Callbacks --

  @impl true
  def init(opts) do
    grace_period_ms = Keyword.get(opts, :grace_period_ms, @default_grace_period_ms)
    {:ok, %{tasks: %{}, grace_period_ms: grace_period_ms}}
  end

  @impl true
  def handle_cast({:available, task_id}, state) do
    case Map.pop(state.tasks, task_id) do
      {%{timer_ref: ref}, tasks} ->
        Process.cancel_timer(ref)
        {:noreply, %{state | tasks: tasks}}

      {nil, _tasks} ->
        {:noreply, state}
    end
  end

  def handle_cast({:unavailable, task_id, cancel_fn}, state) do
    timer_ref = Process.send_after(self(), {:grace_expired, task_id}, state.grace_period_ms)

    tasks = Map.put(state.tasks, task_id, %{timer_ref: timer_ref, cancel_fn: cancel_fn})
    {:noreply, %{state | tasks: tasks}}
  end

  @impl true
  def handle_info({:grace_expired, task_id}, state) do
    case Map.pop(state.tasks, task_id) do
      {%{cancel_fn: cancel_fn}, tasks} ->
        Logger.info("MCP grace period expired for task #{task_id}, cancelling execution")
        cancel_fn.()
        {:noreply, %{state | tasks: tasks}}

      {nil, _tasks} ->
        {:noreply, state}
    end
  end
end
