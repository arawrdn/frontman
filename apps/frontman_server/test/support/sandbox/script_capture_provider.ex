defmodule FrontmanServer.Test.Support.Sandbox.ScriptCaptureProvider do
  @moduledoc false

  @behaviour FrontmanServer.Sandbox.Provider

  alias FrontmanServer.Sandbox.EnvironmentSpec

  @table __MODULE__

  @spec reset!() :: :ok
  def reset! do
    table = ensure_table()
    :ets.delete_all_objects(table)
    :ok
  end

  @spec exec_calls(String.t()) :: [map()]
  def exec_calls(ref) when is_binary(ref) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [{{:state, ^ref}, %{exec_calls: exec_calls}}] -> exec_calls
      [] -> []
    end
  end

  @impl true
  def create(%EnvironmentSpec{} = spec, _opts \\ []) do
    table = ensure_table()
    ref = "script-capture-#{spec.name}-#{System.unique_integer([:positive])}"

    state = %{running: true, exec_calls: []}
    true = :ets.insert(table, {{:state, ref}, state})
    {:ok, ref}
  end

  @impl true
  def exec(ref, command, args, _opts)
      when is_binary(ref) and is_binary(command) and is_list(args) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [{{:state, ^ref}, state}] ->
        exec_call = %{command: command, args: args}

        true =
          :ets.insert(
            table,
            {{:state, ref}, %{state | exec_calls: state.exec_calls ++ [exec_call]}}
          )

        {:ok, %{exit_code: 0, stdout: "ok\n", stderr: ""}}

      [] ->
        {:error, :not_found}
    end
  end

  @impl true
  def metrics(ref) when is_binary(ref) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [{{:state, ^ref}, %{running: running}}] -> {:ok, %{running: running}}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def stop(ref) when is_binary(ref), do: update_running(ref, false)

  @impl true
  def start(ref) when is_binary(ref), do: update_running(ref, true)

  @impl true
  def destroy(ref) when is_binary(ref) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [] ->
        {:error, :not_found}

      [_] ->
        :ets.delete(table, {:state, ref})
        :ok
    end
  end

  defp update_running(ref, running) do
    table = ensure_table()

    case :ets.lookup(table, {:state, ref}) do
      [{{:state, ^ref}, state}] ->
        true = :ets.insert(table, {{:state, ref}, %{state | running: running}})
        :ok

      [] ->
        {:error, :not_found}
    end
  end

  defp ensure_table do
    case :ets.whereis(@table) do
      :undefined -> :ets.new(@table, [:named_table, :public, :set])
      table -> table
    end
  end
end
