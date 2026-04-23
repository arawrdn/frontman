defmodule FrontmanServer.Sandbox.CommandRunner.System do
  @moduledoc false

  @behaviour FrontmanServer.Sandbox.CommandRunner

  @impl true
  def run(command, args, opts) do
    {timeout, system_opts} = Keyword.pop(opts, :timeout)

    case timeout do
      timeout when is_integer(timeout) and timeout > 0 ->
        run_with_timeout(command, args, system_opts, timeout)

      _ ->
        System.cmd(command, args, system_opts)
    end
  end

  defp run_with_timeout(command, args, opts, timeout) do
    task = Task.async(fn -> System.cmd(command, args, opts) end)

    case Task.yield(task, timeout) do
      {:ok, result} ->
        result

      {:exit, reason} ->
        exit(reason)

      nil ->
        _ = Task.shutdown(task, :brutal_kill)
        {"Command timed out after #{timeout}ms\n", 124}
    end
  end
end
