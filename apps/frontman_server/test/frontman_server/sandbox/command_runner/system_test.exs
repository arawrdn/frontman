defmodule FrontmanServer.Sandbox.CommandRunner.SystemTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Sandbox.CommandRunner.System, as: CommandRunnerSystem

  test "supports timeout option and returns a timeout exit code" do
    {output, exit_code} =
      CommandRunnerSystem.run("bash", ["-lc", "sleep 2"], timeout: 50, stderr_to_stdout: true)

    assert exit_code == 124
    assert output =~ "timed out"
  end

  test "returns command output when it completes before timeout" do
    assert {"ok\n", 0} =
             CommandRunnerSystem.run("bash", ["-lc", "printf 'ok\\n'"],
               timeout: 5_000,
               stderr_to_stdout: true
             )
  end
end
