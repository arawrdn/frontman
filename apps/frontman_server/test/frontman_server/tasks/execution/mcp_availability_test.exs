defmodule FrontmanServer.Tasks.Execution.MCPAvailabilityTest do
  use ExUnit.Case, async: true

  alias FrontmanServer.Tasks.Execution.MCPAvailability

  # Use a short grace period for fast tests
  @grace_period_ms 50

  setup do
    monitor = start_supervised!({MCPAvailability, grace_period_ms: @grace_period_ms})
    {:ok, monitor: monitor}
  end

  describe "mcp_server_unavailable -> grace period -> cancel" do
    test "calls cancel_fn after grace period expires", %{monitor: monitor} do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancelled) end

      MCPAvailability.mcp_server_unavailable(monitor, "task-1", cancel_fn)

      refute_receive :cancelled, 10
      assert_receive :cancelled, 100
    end

    test "does not cancel if mcp_server_available is called within grace period", %{
      monitor: monitor
    } do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancelled) end

      MCPAvailability.mcp_server_unavailable(monitor, "task-1", cancel_fn)
      MCPAvailability.mcp_server_available(monitor, "task-1")

      refute_receive :cancelled, 100
    end
  end

  describe "mcp_server_available with no pending timer" do
    test "is a no-op", %{monitor: monitor} do
      MCPAvailability.mcp_server_available(monitor, "task-1")
    end
  end

  describe "disconnect -> reconnect -> disconnect cycle" do
    test "starts a new grace period on second disconnect", %{monitor: monitor} do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancelled) end

      MCPAvailability.mcp_server_unavailable(monitor, "task-1", cancel_fn)
      MCPAvailability.mcp_server_available(monitor, "task-1")
      MCPAvailability.mcp_server_unavailable(monitor, "task-1", cancel_fn)

      assert_receive :cancelled, 100
    end
  end

  describe "multiple tasks" do
    test "tracks tasks independently", %{monitor: monitor} do
      test_pid = self()
      cancel_fn_1 = fn -> send(test_pid, {:cancelled, "task-1"}) end
      cancel_fn_2 = fn -> send(test_pid, {:cancelled, "task-2"}) end

      MCPAvailability.mcp_server_unavailable(monitor, "task-1", cancel_fn_1)
      MCPAvailability.mcp_server_unavailable(monitor, "task-2", cancel_fn_2)

      MCPAvailability.mcp_server_available(monitor, "task-1")

      refute_receive {:cancelled, "task-1"}, 100
      assert_receive {:cancelled, "task-2"}, 100
    end
  end

  describe "timer race conditions" do
    test "expired timer for already-reconnected task is a no-op", %{monitor: monitor} do
      test_pid = self()
      cancel_fn = fn -> send(test_pid, :cancelled) end

      MCPAvailability.mcp_server_unavailable(monitor, "task-1", cancel_fn)
      MCPAvailability.mcp_server_available(monitor, "task-1")

      refute_receive :cancelled, 100
    end
  end
end
