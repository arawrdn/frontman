defmodule FrontmanServer.Tasks.Execution.MCPToolBroadcastTest do
  @moduledoc """
  Tests for agent execution flow.

  These tests exercise the full agent execution using test LLM implementations
  from SwarmCase, catching issues like duplicate tool call broadcasts.
  """

  use FrontmanServer.ExecutionCase

  @moduletag :capture_log

  import FrontmanServer.InteractionCase.Helpers

  import FrontmanServer.BillingFixtures
  import FrontmanServer.Test.Fixtures.Accounts
  import FrontmanServer.Test.Fixtures.Tasks

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Tasks

  describe "MCP tool call broadcast" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      scope = user_scope_fixture()
      subscription_for_scope_fixture(scope)
      task_id = task_with_pubsub_fixture(scope, framework: "nextjs")

      {:ok, task_id: task_id, scope: scope}
    end

    test "broadcasts tool call interaction exactly once for MCP tools", %{
      task_id: task_id,
      scope: scope
    } do
      # Create a tool call that will be routed to MCP (not a backend tool)
      mcp_tool_call = swarm_tool_call("some_mcp_tool", ~s({"arg": "value"}))

      # Provide a tool def so ParallelExecutor can find and route the call
      some_mcp_tool_def =
        SwarmAi.Tool.new(
          name: "some_mcp_tool",
          description: "A test MCP tool",
          parameter_schema: %{},
          timeout_ms: 60_000,
          on_timeout: :pause_agent
        )

      # Create an LLM that returns a tool call on first turn, then completes
      expect_llm_responses([{:tool_calls, [mcp_tool_call], "Done!"}])

      {:ok, _} =
        Tasks.submit_user_message(
          scope,
          task_id,
          user_content("Please call the MCP tool"),
          [some_mcp_tool_def]
        )

      assert_receive {:interaction, %Tasks.Interaction.ToolCall{tool_call_id: tool_call_id}},
                     1_000

      assert tool_call_id == mcp_tool_call.id

      # THE KEY ASSERTION: tool call should be broadcast exactly ONCE
      # If this fails with count > 1, we have the duplicate bug
      refute_receive {:interaction, %Tasks.Interaction.ToolCall{tool_call_id: ^tool_call_id}},
                     50
    end
  end

  describe "MCP tool registration timing" do
    setup do
      pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: true)
      on_exit(fn -> Sandbox.stop_owner(pid) end)

      scope = user_scope_fixture()
      subscription_for_scope_fixture(scope)
      task_id = task_with_pubsub_fixture(scope, framework: "nextjs")

      {:ok, task_id: task_id, scope: scope}
    end

    test "agent is registered before interaction is broadcast", %{task_id: task_id, scope: scope} do
      # Verify registration happens BEFORE broadcast to prevent race condition.
      # ToolExecutor registers in AgentRegistry, then publishes interaction.
      # When we receive the interaction broadcast, the agent should be registered.
      mcp_tool_call = swarm_tool_call("mcp_tool")
      expected_id = mcp_tool_call.id

      mcp_tool_def =
        SwarmAi.Tool.new(
          name: "mcp_tool",
          description: "A test MCP tool",
          parameter_schema: %{},
          timeout_ms: 60_000,
          on_timeout: :pause_agent
        )

      expect_llm_responses([{:tool_calls, [mcp_tool_call], "Done!"}])

      {:ok, _} =
        Tasks.submit_user_message(scope, task_id, user_content("Call tool"), [mcp_tool_def])

      # Wait for the interaction broadcast
      assert_receive {:interaction, %Tasks.Interaction.ToolCall{tool_call_id: ^expected_id}},
                     5_000

      # At this point, agent should be registered for the tool call
      registered =
        case Registry.lookup(FrontmanServer.ToolCallRegistry, {:tool_call, expected_id}) do
          [{_pid, _}] -> true
          [] -> false
        end

      assert registered,
             "Agent not registered when tool call broadcast - race condition exists"
    end
  end
end
