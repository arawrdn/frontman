defmodule FrontmanServerWeb.TaskChannelSentryTest do
  @moduledoc """
  Integration tests verifying Sentry error reporting for tool failures in TaskChannel.

  Tests from issue #474:
  - Gap 1: Backend tool results send "failed" status (not "error") to client
  - Gap 4: MCP tool errors are reported to Sentry
  """

  use FrontmanServerWeb.ChannelCase, async: false

  setup %{scope: scope} do
    Sentry.Test.start_collecting_sentry_reports()

    {socket, task_id} = join_task_channel(scope, framework: "test-framework")
    complete_mcp_handshake(socket)

    {:ok, socket: socket, task_id: task_id}
  end

  describe "backend tool result status normalization (Gap 1)" do
    test "sends 'failed' status for backend tool errors (not 'error')", %{
      socket: socket,
      task_id: task_id
    } do
      tool_result =
        build_tool_result(
          tool_name: "search_codebase",
          result: "Search failed",
          is_error: true
        )

      send(socket.channel_pid, {:interaction, tool_result})

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => _,
            "status" => "failed"
          }
        }
      })
    end

    test "sends 'completed' status for successful backend tool results", %{
      socket: socket,
      task_id: task_id
    } do
      tool_result = build_tool_result(tool_name: "todo_list", result: "[]", is_error: false)

      send(socket.channel_pid, {:interaction, tool_result})

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "status" => "completed"
          }
        }
      })
    end
  end

  describe "MCP tool error Sentry reporting (Gap 4)" do
    test "reports MCP tool error to Sentry with context", %{
      socket: socket,
      task_id: task_id
    } do
      tool_call =
        build_tool_call(
          tool_name: "testMcpTool",
          arguments: %{"key" => "value"}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "testMcpTool"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.error_response(
          mcp_request_id,
          -32_000,
          "Tool execution failed: permission denied"
        )
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "status" => "failed"
          }
        }
      })

      reports = Sentry.Test.pop_sentry_reports()

      mcp_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "mcp_tool_error"
        end)

      assert [report] = mcp_error_reports
      assert report.message.formatted == "MCP tool execution failed"
      assert report.extra[:tool_name] == "testMcpTool"
      assert report.extra[:task_id] == task_id
      assert report.extra[:error_message] =~ "permission denied"
    end

    test "MCP tool error with missing message field defaults to 'Unknown MCP error'", %{
      socket: socket
    } do
      tool_call = build_tool_call(tool_name: "anotherMcpTool")

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.error_response(mcp_request_id, -32_000, "Unknown MCP error")
      )

      :sys.get_state(socket.channel_pid)

      reports = Sentry.Test.pop_sentry_reports()

      mcp_error_reports =
        Enum.filter(reports, fn event ->
          event.tags[:error_type] == "mcp_tool_error"
        end)

      assert [report] = mcp_error_reports
      assert report.extra[:error_message] == "Unknown MCP error"
    end
  end
end
