defmodule FrontmanServerWeb.TaskChannelTest do
  use FrontmanServerWeb.ChannelCase, async: true

  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction

  # ---------------------------------------------------------------------------
  # Tools fixtures used by specific handshake variants
  # ---------------------------------------------------------------------------

  @standard_tools %{
    "tools" => [
      %{
        "name" => "get_logs",
        "description" => "Retrieves server logs",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{"tail" => %{"type" => "integer"}}
        },
        "visibleToAgent" => true
      }
    ]
  }

  @interactive_tools %{
    "tools" => [
      %{
        "name" => "question",
        "description" => "Ask the user a question",
        "inputSchema" => %{
          "type" => "object",
          "properties" => %{"questions" => %{"type" => "array"}}
        },
        "executionMode" => "Interactive"
      }
    ]
  }

  # ---------------------------------------------------------------------------
  # Tests
  # ---------------------------------------------------------------------------

  describe "join task:<id>" do
    test "succeeds when task exists", %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)

      assert socket.assigns.task_id == task_id
    end

    test "fails when task does not exist", %{scope: scope} do
      nonexistent_task_id = Ecto.UUID.generate()

      {:error, reply} =
        FrontmanServerWeb.UserSocket
        |> socket("user_id", %{scope: scope})
        |> subscribe_and_join("task:#{nonexistent_task_id}", %{})

      assert reply == %{reason: "task_not_found"}
    end
  end

  describe "session/prompt" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "returns error for unknown method", %{socket: socket} do
      ref =
        push(socket, "acp:message", %{
          "jsonrpc" => "2.0",
          "id" => 2,
          "method" => "unknown/method"
        })

      assert_reply(ref, :ok, %{"acp:message" => response})
      assert response["error"]["code"] == -32_601
      assert response["error"]["message"] =~ "Method not found"
    end
  end

  describe "PubSub subscription" do
    @moduledoc """
    Tests that verify the channel is properly subscribed to PubSub.

    This is critical because tool calls are broadcast via PubSub from the agent,
    and the channel must receive them to route to MCP. Previous tests used
    send(socket.channel_pid, ...) which bypassed PubSub entirely.
    """

    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "channel receives tool call interactions via PubSub broadcast", %{
      socket: _socket,
      task_id: task_id
    } do
      tool_call = build_tool_call(tool_name: "testTool", arguments: %{"key" => "value"})

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_call}
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "params" => %{"name" => "testTool"}
      })
    end

    test "channel does NOT receive broadcasts to different topics", %{
      socket: _socket,
      task_id: task_id
    } do
      different_topic = "task:different_#{:rand.uniform(1_000_000)}"

      tool_call = build_tool_call(tool_name: "otherTool")

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        different_topic,
        {:interaction, tool_call}
      )

      refute_push("mcp:message", %{"params" => %{"name" => "otherTool"}})

      # But it SHOULD still receive broadcasts to its own topic
      tool_call2 = %{tool_call | tool_name: "ownTool"}

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_call2}
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "params" => %{"name" => "ownTool"}
      })
    end

    test "channel receives agent stream tokens via PubSub broadcast", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:stream_token, "Hello world"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"type" => "text", "text" => "Hello world"}
          }
        }
      })
    end

    test "channel handles stream_thinking without crashing", %{
      socket: socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:stream_thinking, "reasoning about the task..."}
      )

      # Channel should NOT forward thinking tokens to client
      refute_push("acp:message", %{
        "params" => %{"update" => %{"sessionUpdate" => "agent_thinking_chunk"}}
      })

      # But the channel should still be alive and functional
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:stream_token, "after thinking"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "agent_message_chunk",
            "content" => %{"type" => "text", "text" => "after thinking"}
          }
        }
      })

      assert Process.alive?(socket.channel_pid)
    end
  end

  describe "agent_error handling" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "broadcasts error as session/update notification", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:agent_error, "Rate limit exceeded"}
      )

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "Rate limit exceeded"
          }
        }
      })
    end

    test "sends JSON-RPC error response when prompt is pending", %{
      socket: socket,
      task_id: task_id
    } do
      push(socket, "acp:message", build_prompt_request(42, "Hello"))
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:agent_error, "No API key available"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "No API key available"
          }
        }
      })

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 42,
        "error" => %{
          "code" => -32_000,
          "message" => "No API key available"
        }
      })
    end

    test "handles error when no pending prompt (only sends session/update)", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:agent_error, "Connection failed"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "error",
            "message" => "Connection failed"
          }
        }
      })

      refute_push("acp:message", %{"error" => %{"code" => -32_000}})
    end

    test "handles different error messages correctly", %{
      socket: _socket,
      task_id: task_id
    } do
      error_messages = [
        "Free requests exhausted. Add your API key in Settings to continue.",
        "No API key available for this request.",
        "Request failed: connection timeout"
      ]

      for message <- error_messages do
        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          Tasks.topic(task_id),
          {:agent_error, message}
        )

        assert_push("acp:message", %{
          "method" => "session/update",
          "params" => %{
            "update" => %{
              "sessionUpdate" => "error",
              "message" => ^message
            }
          }
        })
      end
    end
  end

  describe "MCP tool call result extraction" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "extracts text content from MCP tool result", %{socket: socket, task_id: task_id} do
      tool_call =
        build_tool_call(
          tool_call_id: "call_123",
          tool_name: "consoleLog",
          arguments: %{"message" => "hello"}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "consoleLog"}
      })

      mcp_tool_result = %{
        "content" => [%{"type" => "text", "text" => "Logged: hello"}]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_tool_result))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => "call_123",
            "status" => "completed",
            "content" => [%{"content" => %{"text" => "Logged: hello"}}]
          }
        }
      })
    end
  end

  describe "MCP initialization" do
    test "sends MCP initialize request on join", %{scope: scope} do
      {_socket, _task_id} = join_task_channel(scope)

      expected_version = ModelContextProtocol.protocol_version()

      assert_push("mcp:message", %{
        "jsonrpc" => "2.0",
        "id" => _id,
        "method" => "initialize",
        "params" => %{
          "protocolVersion" => ^expected_version,
          "clientInfo" => %{"name" => "frontman-server"}
        }
      })
    end

    test "completes handshake and sends initialized notification", %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope)

      assert_push("mcp:message", %{"id" => request_id})

      init_result = %{
        "protocolVersion" => ModelContextProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "browser-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(request_id, init_result))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{
        "jsonrpc" => "2.0",
        "method" => "notifications/initialized"
      })
    end
  end

  describe "MCP response validation" do
    import ExUnit.CaptureLog

    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "rejects response missing jsonrpc field", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"id" => 999, "result" => %{}})
          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{
            "jsonrpc" => "2.0",
            "method" => "error",
            "params" => %{
              "message" => "Invalid JSON-RPC response",
              "reason" => "invalid_message"
            }
          })
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response with wrong jsonrpc version", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "1.0", "id" => 999, "result" => %{}})
          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{
            "method" => "error",
            "params" => %{"reason" => "invalid_version"}
          })
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response missing id", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{"jsonrpc" => "2.0", "result" => %{}})
          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{"method" => "error"})
        end)

      assert log =~ "Invalid MCP response"
    end

    test "rejects response with both result and error", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{
            "jsonrpc" => "2.0",
            "id" => 999,
            "result" => %{},
            "error" => %{"code" => -32_601, "message" => "Error"}
          })

          :sys.get_state(socket.channel_pid)

          assert_push("mcp:message", %{"method" => "error"})
        end)

      assert log =~ "Invalid MCP response"
    end

    test "accepts valid MCP response", %{socket: socket, task_id: task_id} do
      tool_call = build_tool_call(tool_call_id: "call_valid_test", tool_name: "testTool")

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{"method" => "tools/call", "id" => mcp_request_id})

      mcp_result = %{"content" => [%{"type" => "text", "text" => "Success"}]}
      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_result))
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{"status" => "completed"}
        }
      })
    end
  end

  describe "MCP tool result flows to waiting executor" do
    @moduletag timeout: 30_000

    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake_with_tools(socket, @standard_tools)
      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "delivers tool response to executor regardless of initialization state", %{scope: scope} do
      # Tool responses should always be delivered to waiting executors.
      # This ensures agents can function even if tool calls happen early in the session.

      {socket, _fresh_task_id} = join_task_channel(scope)

      # Drain the initialize request without responding - initialization is incomplete
      assert_push("mcp:message", %{"id" => _init_request_id, "method" => "initialize"})

      tool_call_id = "call_delivery_#{:rand.uniform(1_000_000)}"
      test_pid = self()

      # Executor registers and waits for tool result
      Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}, %{
        caller_pid: test_pid
      })

      tool_call =
        build_tool_call(
          tool_call_id: tool_call_id,
          tool_name: "list_dir",
          arguments: %{"path" => "/"}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "list_dir"}
      })

      tool_result = %{
        "content" => [%{"type" => "text", "text" => "file1.txt\nfile2.txt"}]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, tool_result))

      assert_receive {:tool_result, ^tool_call_id, content, false}, 5_000

      assert is_binary(content)
      assert content =~ "file1.txt"

      Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
    end

    test "encodes JSON tool result to string for waiting executor", %{socket: socket} do
      # This test exercises the full flow where:
      # 1. An executor is waiting for a tool result (registered in AgentRegistry)
      # 2. MCP tool returns JSON that gets parsed to a map
      # 3. The result should be encoded to string before sending to executor

      tool_call_id = "call_json_result_#{:rand.uniform(1_000_000)}"
      test_pid = self()

      Registry.register(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id}, %{
        caller_pid: test_pid
      })

      tool_call =
        build_tool_call(
          tool_call_id: tool_call_id,
          tool_name: "get_logs",
          arguments: %{"tail" => 10}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "get_logs"}
      })

      json_result = %{
        "content" => [
          %{
            "type" => "text",
            "text" =>
              Jason.encode!(%{
                "logs" => [
                  %{
                    "timestamp" => "2026-01-05T10:42:21.102Z",
                    "level" => "console",
                    "message" => "GET / 200 261.81ms"
                  }
                ],
                "totalMatched" => 1,
                "bufferSize" => 1,
                "hasMore" => false
              })
          }
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, json_result))

      assert_receive {:tool_result, ^tool_call_id, content, false}, 5_000

      assert is_binary(content),
             "Tool result should be encoded to string, got: #{inspect(content)}"

      assert {:ok, decoded} = Jason.decode(content)
      assert is_map(decoded)
      assert Map.has_key?(decoded, "logs")

      Registry.unregister(FrontmanServer.ToolCallRegistry, {:tool_call, tool_call_id})
    end
  end

  describe "MCP tools race condition" do
    test "queued prompt is processed with MCP tools after initialization completes", %{
      scope: scope
    } do
      # Verifies the prompt queuing mechanism:
      # 1. Prompt sent before MCP init is queued in socket assigns
      # 2. MCP init completes, storing tools in socket assigns
      # 3. Queued prompt is processed with the loaded MCP tools

      {socket, _task_id} = join_task_channel(scope)

      # MCP init has started - we receive the initialize request
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      # Send prompt BEFORE completing MCP handshake
      push(socket, "acp:message", build_prompt_request(1, "Implement the header"))
      :sys.get_state(socket.channel_pid)

      # NOW complete MCP init with tools
      init_result = %{
        "protocolVersion" => ModelContextProtocol.protocol_version(),
        "capabilities" => %{"tools" => %{}},
        "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
      }

      push(socket, "mcp:message", JsonRpc.success_response(init_request_id, init_result))
      :sys.get_state(socket.channel_pid)

      assert_push("mcp:message", %{"method" => "notifications/initialized"})
      assert_push("mcp:message", %{"id" => tools_request_id, "method" => "tools/list"})

      tools_result = %{
        "tools" => [
          %{
            "name" => "take_screenshot",
            "description" => "Takes a screenshot of the page",
            "inputSchema" => %{"type" => "object", "properties" => %{}}
          }
        ]
      }

      push(socket, "mcp:message", JsonRpc.success_response(tools_request_id, tools_result))
      :sys.get_state(socket.channel_pid)

      # Handle load_agent_instructions
      assert_push("mcp:message", %{
        "id" => project_rules_request_id,
        "method" => "tools/call",
        "params" => %{"name" => "load_agent_instructions"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(project_rules_request_id, %{"content" => []})
      )

      :sys.get_state(socket.channel_pid)

      # Handle list_tree for project structure
      assert_push("mcp:message", %{
        "id" => project_structure_request_id,
        "method" => "tools/call",
        "params" => %{"name" => "list_tree"}
      })

      push(
        socket,
        "mcp:message",
        JsonRpc.success_response(project_structure_request_id, %{"content" => []})
      )

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{"method" => "mcp_initialization_complete"})

      # Verify MCP tools are now stored in socket assigns
      channel_socket = :sys.get_state(socket.channel_pid)
      assert length(channel_socket.assigns.mcp_tools) == 1
      assert hd(channel_socket.assigns.mcp_tools).name == "take_screenshot"

      # After MCP init completes, the queued prompt is processed
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    end
  end

  describe "session/cancel" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "cancel notification is accepted (no response expected per ACP spec)", %{
      socket: socket
    } do
      cancel_notification = %{
        "jsonrpc" => "2.0",
        "method" => "session/cancel",
        "params" => %{"sessionId" => "irrelevant"}
      }

      push(socket, "acp:message", cancel_notification)
      :sys.get_state(socket.channel_pid)

      refute_push("acp:message", %{"id" => _})
    end

    test "cancel resolves pending prompt with stopReason 'cancelled'", %{
      socket: socket,
      task_id: task_id
    } do
      push(socket, "acp:message", build_prompt_request(99, "Hello"))
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_cancelled
      )

      # Always sends notification (canonical turn-ended signal)
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_turn_complete",
            "stopReason" => "cancelled"
          }
        }
      })

      # Also resolves the pending RPC
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 99,
        "result" => %{"stopReason" => "cancelled"}
      })
    end

    test "cancel with no pending prompt sends notification", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_cancelled
      )

      # Notification is always sent (the canonical turn-ended signal)
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_turn_complete",
            "stopReason" => "cancelled"
          }
        }
      })

      # No RPC response since there's no pending prompt
      refute_push("acp:message", %{"id" => _, "result" => %{"stopReason" => "cancelled"}})
    end

    test "cancel does not interfere with subsequent prompts", %{
      socket: socket,
      task_id: task_id
    } do
      push(socket, "acp:message", build_prompt_request(1, "Hello"))
      :sys.get_state(socket.channel_pid)

      # Cancel it
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_cancelled
      )

      assert_push("acp:message", %{
        "id" => 1,
        "result" => %{"stopReason" => "cancelled"}
      })

      # Send a second prompt - this should work normally
      push(socket, "acp:message", build_prompt_request(2, "Follow up"))
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_completed
      )

      assert_push("acp:message", %{
        "id" => 2,
        "result" => %{"stopReason" => "end_turn"}
      })
    end
  end

  describe "tool_call_start streaming" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "broadcasts early ACP tool_call notification on tool_call_start", %{
      socket: _socket,
      task_id: task_id
    } do
      tool_call_id = "call_early_#{:rand.uniform(1_000_000)}"

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:tool_call_start, tool_call_id, "write_file"}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id,
            "title" => "write_file",
            "status" => "pending"
          }
        }
      })
    end

    test "deduplicates tool_call_create when interaction arrives after tool_call_start", %{
      socket: socket,
      task_id: _task_id
    } do
      tool_call_id = "call_dedup_#{:rand.uniform(1_000_000)}"

      # Step 1: Send tool_call_start (early streaming notification)
      send(socket.channel_pid, {:tool_call_start, tool_call_id, "write_file"})
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id
          }
        }
      })

      # Step 2: Send the full interaction
      tool_call =
        build_tool_call(
          tool_call_id: tool_call_id,
          tool_name: "write_file",
          arguments: %{"target_file" => "test.txt", "content" => "hello"}
        )

      send(socket.channel_pid, {:interaction, tool_call})
      :sys.get_state(socket.channel_pid)

      # Should get a tool_call_update with args, but NOT a duplicate tool_call create
      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "pending"
          }
        }
      })

      refute_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id
          }
        }
      })
    end

    test "sends tool_call_create for interactions without prior tool_call_start", %{
      socket: socket,
      task_id: task_id
    } do
      tool_call_id = "call_no_start_#{:rand.uniform(1_000_000)}"

      tool_call = build_tool_call(tool_call_id: tool_call_id, tool_name: "take_screenshot")

      send(socket.channel_pid, {:interaction, tool_call})
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "tool_call",
            "toolCallId" => ^tool_call_id
          }
        }
      })

      assert_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id
          }
        }
      })
    end

    test "tracks multiple tool calls independently", %{
      socket: socket
    } do
      call_id_1 = "call_multi_1_#{:rand.uniform(1_000_000)}"
      call_id_2 = "call_multi_2_#{:rand.uniform(1_000_000)}"

      # Announce first tool call via streaming
      send(socket.channel_pid, {:tool_call_start, call_id_1, "write_file"})
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"toolCallId" => ^call_id_1, "sessionUpdate" => "tool_call"}}
      })

      # Second tool call arrives without prior tool_call_start
      tool_call_2 =
        build_tool_call(
          tool_call_id: call_id_2,
          tool_name: "read_file",
          arguments: %{"target_file" => "other.txt"}
        )

      send(socket.channel_pid, {:interaction, tool_call_2})
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "params" => %{"update" => %{"toolCallId" => ^call_id_2, "sessionUpdate" => "tool_call"}}
      })
    end
  end

  describe "interactive tool flow (question tool)" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake_with_tools(socket, @interactive_tools)
      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "agent_suspended broadcast does not crash the channel", %{
      socket: socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_suspended
      )

      state = :sys.get_state(socket.channel_pid)
      assert state != nil

      # The channel should NOT resolve the pending prompt
      refute_push("acp:message", %{"result" => _})
    end

    test "agent_suspended does not resolve pending prompt", %{
      socket: socket,
      task_id: task_id
    } do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 42,
        "method" => "session/prompt",
        "params" => %{
          "sessionId" => task_id,
          "content" => "test prompt"
        }
      })

      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_suspended
      )

      :sys.get_state(socket.channel_pid)

      refute_push("acp:message", %{"id" => 42, "result" => _})
    end

    test "interactive tool call does not get added to pending_requests", %{
      socket: socket,
      task_id: task_id
    } do
      tool_call = build_tool_call(tool_name: "question", arguments: %{"questions" => []})

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_call}
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => _mcp_request_id,
        "params" => %{"name" => "question"}
      })

      state = :sys.get_state(socket.channel_pid)
      pending = state.assigns[:pending_requests] || %{}
      assert pending == %{}
    end

    test "non-interactive tool call IS added to pending_requests", %{
      socket: socket,
      task_id: task_id
    } do
      tool_call = build_tool_call(tool_name: "list_dir", arguments: %{"path" => "/"})

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_call}
      )

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => _mcp_request_id,
        "params" => %{"name" => "list_dir"}
      })

      state = :sys.get_state(socket.channel_pid)
      pending = state.assigns[:pending_requests] || %{}
      assert map_size(pending) == 1
    end

    test "tool:submit_result persists tool result interaction", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      tool_call_id = "call_question_submit_#{:rand.uniform(1_000_000)}"

      # First, add a ToolCall interaction so the ToolResult has a parent
      reqllm_tc = ReqLLM.ToolCall.new(tool_call_id, "question", "{}")
      {:ok, _interaction} = Tasks.add_tool_call(scope, task_id, reqllm_tc)

      push(socket, "tool:submit_result", %{
        "tool_call_id" => tool_call_id,
        "tool_name" => "question",
        "result" => Jason.encode!(%{"answers" => [%{"answer" => "yes"}]}),
        "is_error" => false,
        "metadata" => %{}
      })

      # Wait for processing (handler triggers maybe_resume_after_tool_result)
      Process.sleep(200)
      :sys.get_state(socket.channel_pid)

      {:ok, task} = Tasks.get_task(scope, task_id)

      tool_results =
        task.interactions
        |> Enum.filter(&match?(%Interaction.ToolResult{}, &1))

      assert tool_results != []

      matching =
        Enum.find(tool_results, fn tr -> tr.tool_call_id == tool_call_id end)

      assert matching != nil
      assert matching.tool_name == "question"
    end

    test "tool:submit_result sends ACP completion notification", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      tool_call_id = "call_question_notify_#{:rand.uniform(1_000_000)}"

      reqllm_tc = ReqLLM.ToolCall.new(tool_call_id, "question", "{}")
      {:ok, _interaction} = Tasks.add_tool_call(scope, task_id, reqllm_tc)

      push(socket, "tool:submit_result", %{
        "tool_call_id" => tool_call_id,
        "tool_name" => "question",
        "result" => "answered",
        "is_error" => false,
        "metadata" => %{}
      })

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "completed"
          }
        }
      })
    end

    test "tool:submit_result with is_error sends ACP failed notification", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      tool_call_id = "call_question_error_#{:rand.uniform(1_000_000)}"

      reqllm_tc = ReqLLM.ToolCall.new(tool_call_id, "question", "{}")
      {:ok, _interaction} = Tasks.add_tool_call(scope, task_id, reqllm_tc)

      push(socket, "tool:submit_result", %{
        "tool_call_id" => tool_call_id,
        "tool_name" => "question",
        "result" => "User cancelled the question",
        "is_error" => true,
        "metadata" => %{}
      })

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "failed"
          }
        }
      })

      # Verify the error result is persisted
      Process.sleep(100)
      {:ok, task} = Tasks.get_task(scope, task_id)

      error_result =
        task.interactions
        |> Enum.find(fn
          %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
          _ -> false
        end)

      assert error_result != nil
      assert error_result.is_error == true
    end
  end

  # ---------------------------------------------------------------------------
  # CRITICAL: tool:submit_result when MCP initialization is pending
  # ---------------------------------------------------------------------------

  describe "tool:submit_result with MCP pending (server restart scenario)" do
    # These tests simulate a client reconnecting after a server restart and
    # submitting a pending tool result before MCP initialization completes.
    # The channel must NOT attempt to resume execution with empty tools.

    test "persists tool result even when MCP is still initializing", %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)

      # Drain the MCP initialize request but do NOT complete the handshake
      assert_push("mcp:message", %{"id" => _init_request_id, "method" => "initialize"})

      # Verify MCP is still pending
      channel_state = :sys.get_state(socket.channel_pid)
      assert channel_state.assigns.mcp_status == :pending

      tool_call_id = "call_pending_mcp_#{:rand.uniform(1_000_000)}"
      reqllm_tc = ReqLLM.ToolCall.new(tool_call_id, "question", "{}")
      {:ok, _interaction} = Tasks.add_tool_call(scope, task_id, reqllm_tc)

      push(socket, "tool:submit_result", %{
        "tool_call_id" => tool_call_id,
        "tool_name" => "question",
        "result" => Jason.encode!(%{"answers" => [%{"answer" => "yes"}]}),
        "is_error" => false,
        "metadata" => %{}
      })

      Process.sleep(200)
      :sys.get_state(socket.channel_pid)

      # The tool result should still be persisted in DB regardless of MCP status
      {:ok, task} = Tasks.get_task(scope, task_id)

      matching =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
          _ -> false
        end)

      assert matching != nil
      assert matching.tool_name == "question"
    end

    test "sends ACP notification even when MCP is still initializing", %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      assert_push("mcp:message", %{"id" => _init_request_id, "method" => "initialize"})

      tool_call_id = "call_pending_acp_#{:rand.uniform(1_000_000)}"
      reqllm_tc = ReqLLM.ToolCall.new(tool_call_id, "question", "{}")
      {:ok, _interaction} = Tasks.add_tool_call(scope, task_id, reqllm_tc)

      push(socket, "tool:submit_result", %{
        "tool_call_id" => tool_call_id,
        "tool_name" => "question",
        "result" => "answered",
        "is_error" => false,
        "metadata" => %{}
      })

      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "completed"
          }
        }
      })
    end

    test "mcp_tools is empty when MCP is still initializing", %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope)
      assert_push("mcp:message", %{"id" => _init_request_id, "method" => "initialize"})

      channel_state = :sys.get_state(socket.channel_pid)
      assert channel_state.assigns[:mcp_tools] == nil
      assert channel_state.assigns.mcp_status == :pending
    end
  end

  # ---------------------------------------------------------------------------
  # CRITICAL: agent_completed with nil pending_prompt_id
  # ---------------------------------------------------------------------------

  describe "agent_completed without pending prompt (resume scenario)" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "sends agent_turn_complete notification when pending_prompt_id is nil", %{
      socket: socket,
      task_id: task_id
    } do
      # Simulate: execution was resumed after tool result (no pending prompt),
      # then the agent completes. There's no JSON-RPC request to respond to.
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_completed
      )

      :sys.get_state(socket.channel_pid)

      # Channel should NOT push a JSON-RPC response since there's no pending prompt
      refute_push("acp:message", %{"id" => _, "result" => _})

      # Channel SHOULD push an agent_turn_complete notification so the client
      # can finalize the streaming message and reset its agent-running state.
      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "agent_turn_complete",
            "stopReason" => "end_turn"
          }
        }
      })

      # Channel should still be alive
      assert Process.alive?(socket.channel_pid)
    end

    test "does not interfere with subsequent prompts after nil completion", %{
      socket: socket,
      task_id: task_id
    } do
      # First: agent_completed with no pending prompt
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_completed
      )

      :sys.get_state(socket.channel_pid)

      # Then: send a real prompt and complete it normally
      push(socket, "acp:message", build_prompt_request(50, "Next question"))
      :sys.get_state(socket.channel_pid)

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        :agent_completed
      )

      assert_push("acp:message", %{
        "jsonrpc" => "2.0",
        "id" => 50,
        "result" => %{"stopReason" => "end_turn"}
      })
    end
  end

  # ---------------------------------------------------------------------------
  # CRITICAL: MCP tool call response resume with stale state
  # ---------------------------------------------------------------------------

  describe "MCP tool call response with stale execution state" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake_with_tools(socket, @standard_tools)
      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "last_execution_tools and last_execution_opts are nil before any prompt", %{
      socket: socket
    } do
      channel_state = :sys.get_state(socket.channel_pid)
      assert channel_state.assigns[:last_execution_tools] == nil
      assert channel_state.assigns[:last_execution_opts] == nil
    end

    test "tool call response persists result even when last_execution state is nil", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      # Simulate a tool call arriving without a preceding prompt
      # (e.g. after reconnect when execution state is stale)
      tool_call_id = "call_stale_#{:rand.uniform(1_000_000)}"

      tool_call =
        build_tool_call(
          tool_call_id: tool_call_id,
          tool_name: "get_logs",
          arguments: %{"tail" => 5}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "get_logs"}
      })

      mcp_result = %{"content" => [%{"type" => "text", "text" => "log output"}]}
      push(socket, "mcp:message", JsonRpc.success_response(mcp_request_id, mcp_result))
      :sys.get_state(socket.channel_pid)

      # Result should be persisted
      Process.sleep(100)
      {:ok, task} = Tasks.get_task(scope, task_id)

      matching =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
          _ -> false
        end)

      assert matching != nil

      # ACP update should be sent
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "completed"
          }
        }
      })
    end
  end

  # ---------------------------------------------------------------------------
  # HIGH: MCP tool call error handling
  # ---------------------------------------------------------------------------

  describe "MCP tool call error response" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake_with_tools(socket, @standard_tools)
      {:ok, socket: socket, task_id: task_id, scope: scope}
    end

    test "persists error result and sends ACP failed notification", %{
      socket: socket,
      task_id: task_id,
      scope: scope
    } do
      tool_call_id = "call_mcp_err_#{:rand.uniform(1_000_000)}"

      tool_call =
        build_tool_call(
          tool_call_id: tool_call_id,
          tool_name: "get_logs",
          arguments: %{"tail" => 10}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id,
        "params" => %{"name" => "get_logs"}
      })

      # Send a JSON-RPC error response instead of success
      error_response = %{
        "jsonrpc" => "2.0",
        "id" => mcp_request_id,
        "error" => %{
          "code" => -32_000,
          "message" => "Tool execution timed out"
        }
      }

      push(socket, "mcp:message", error_response)
      :sys.get_state(socket.channel_pid)

      # Should send ACP failed notification
      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "failed"
          }
        }
      })

      # Should persist error result in DB
      Process.sleep(100)
      {:ok, task} = Tasks.get_task(scope, task_id)

      error_result =
        Enum.find(task.interactions, fn
          %Interaction.ToolResult{tool_call_id: ^tool_call_id} -> true
          _ -> false
        end)

      assert error_result != nil
      assert error_result.is_error == true
      assert error_result.result =~ "Tool execution timed out"
    end

    test "removes tool call from pending_requests after error", %{socket: socket} do
      tool_call_id = "call_mcp_err_pending_#{:rand.uniform(1_000_000)}"

      tool_call =
        build_tool_call(
          tool_call_id: tool_call_id,
          tool_name: "get_logs",
          arguments: %{"tail" => 1}
        )

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id
      })

      # Verify pending_requests has the tool call
      state_before = :sys.get_state(socket.channel_pid)
      pending_before = state_before.assigns[:pending_requests] || %{}
      assert map_size(pending_before) == 1

      error_response = %{
        "jsonrpc" => "2.0",
        "id" => mcp_request_id,
        "error" => %{"code" => -32_000, "message" => "Error"}
      }

      push(socket, "mcp:message", error_response)
      :sys.get_state(socket.channel_pid)

      # pending_requests should be cleared
      state_after = :sys.get_state(socket.channel_pid)
      pending_after = state_after.assigns[:pending_requests] || %{}
      assert map_size(pending_after) == 0
    end

    test "handles error with missing message field", %{socket: socket} do
      tool_call_id = "call_mcp_err_nomsg_#{:rand.uniform(1_000_000)}"

      tool_call =
        build_tool_call(tool_call_id: tool_call_id, tool_name: "get_logs", arguments: %{})

      send(socket.channel_pid, {:interaction, tool_call})

      assert_push("mcp:message", %{
        "method" => "tools/call",
        "id" => mcp_request_id
      })

      # Error with valid JSON-RPC structure but generic message
      error_response = %{
        "jsonrpc" => "2.0",
        "id" => mcp_request_id,
        "error" => %{"code" => -32_603, "message" => "Internal error"}
      }

      push(socket, "mcp:message", error_response)
      :sys.get_state(socket.channel_pid)

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "failed"
          }
        }
      })

      assert Process.alive?(socket.channel_pid)
    end
  end

  # ---------------------------------------------------------------------------
  # HIGH: ToolResult interaction broadcast handler
  # ---------------------------------------------------------------------------

  describe "ToolResult interaction broadcast" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "pushes ACP tool_call_update for regular tool results", %{
      socket: _socket,
      task_id: task_id
    } do
      tool_call_id = "call_result_broadcast_#{:rand.uniform(1_000_000)}"

      tool_result =
        build_tool_result(
          tool_call_id: tool_call_id,
          tool_name: "get_logs",
          result: "log output here",
          is_error: false
        )

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_result}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "completed"
          }
        }
      })
    end

    test "pushes ACP tool_call_update with failed status for error results", %{
      socket: _socket,
      task_id: task_id
    } do
      tool_call_id = "call_result_err_#{:rand.uniform(1_000_000)}"

      tool_result =
        build_tool_result(
          tool_call_id: tool_call_id,
          tool_name: "get_logs",
          result: "Permission denied",
          is_error: true
        )

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_result}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "failed"
          }
        }
      })
    end

    test "skips ACP notification for todo mutation tool results", %{
      socket: socket,
      task_id: task_id
    } do
      for todo_tool <- ["todo_add", "todo_update", "todo_remove"] do
        tool_call_id = "call_todo_#{todo_tool}_#{:rand.uniform(1_000_000)}"

        tool_result =
          build_tool_result(
            tool_call_id: tool_call_id,
            tool_name: todo_tool,
            result: "ok"
          )

        Phoenix.PubSub.broadcast(
          FrontmanServer.PubSub,
          Tasks.topic(task_id),
          {:interaction, tool_result}
        )
      end

      :sys.get_state(socket.channel_pid)

      # Mutation results should NOT produce tool_call_update notifications
      refute_push("acp:message", %{
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update"
          }
        }
      })

      assert Process.alive?(socket.channel_pid)
    end

    test "todo_list results DO get ACP notification (not a mutation)", %{
      socket: _socket,
      task_id: task_id
    } do
      tool_call_id = "call_todo_list_#{:rand.uniform(1_000_000)}"

      tool_result =
        build_tool_result(
          tool_call_id: tool_call_id,
          tool_name: "todo_list",
          result: "[]"
        )

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:interaction, tool_result}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "tool_call_update",
            "toolCallId" => ^tool_call_id,
            "status" => "completed"
          }
        }
      })
    end
  end

  # ---------------------------------------------------------------------------
  # HIGH: plan_updated broadcast handler
  # ---------------------------------------------------------------------------

  describe "plan_updated broadcast" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "pushes ACP plan update notification", %{
      socket: _socket,
      task_id: task_id
    } do
      entries = [
        %{"content" => "Fix the bug", "priority" => "high", "status" => "in_progress"},
        %{"content" => "Write tests", "priority" => "medium", "status" => "pending"}
      ]

      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:plan_updated, entries}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "sessionId" => ^task_id,
          "update" => %{
            "sessionUpdate" => "plan",
            "entries" => ^entries
          }
        }
      })
    end

    test "handles empty entries list", %{
      socket: _socket,
      task_id: task_id
    } do
      Phoenix.PubSub.broadcast(
        FrontmanServer.PubSub,
        Tasks.topic(task_id),
        {:plan_updated, []}
      )

      assert_push("acp:message", %{
        "method" => "session/update",
        "params" => %{
          "update" => %{
            "sessionUpdate" => "plan",
            "entries" => []
          }
        }
      })
    end
  end

  # ---------------------------------------------------------------------------
  # MEDIUM: handle_prompt with mcp_status :failed
  # ---------------------------------------------------------------------------

  describe "session/prompt with failed MCP initialization" do
    test "processes prompt when MCP init has failed", %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope)

      # Start MCP init
      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      # Fail the MCP init by sending an error response
      error_response = %{
        "jsonrpc" => "2.0",
        "id" => init_request_id,
        "error" => %{
          "code" => -32_603,
          "message" => "MCP server crashed"
        }
      }

      push(socket, "mcp:message", error_response)
      :sys.get_state(socket.channel_pid)

      channel_state = :sys.get_state(socket.channel_pid)
      assert channel_state.assigns.mcp_status == :failed

      # Send a prompt — should be processed despite MCP failure (best effort)
      push(socket, "acp:message", build_prompt_request(10, "Hello despite failure"))
      :sys.get_state(socket.channel_pid)

      # The prompt should be processed (user message added), not queued
      assert_receive {:interaction, %Tasks.Interaction.UserMessage{}}
    end
  end

  # ---------------------------------------------------------------------------
  # MEDIUM: queued prompt processed after MCP init failure
  # ---------------------------------------------------------------------------

  describe "queued prompt with failed MCP initialization" do
    test "queued prompt is processed even when MCP init fails", %{scope: scope} do
      {socket, _task_id} = join_task_channel(scope)

      assert_push("mcp:message", %{"id" => init_request_id, "method" => "initialize"})

      # Queue a prompt while MCP is still initializing
      push(socket, "acp:message", build_prompt_request(20, "Queued before failure"))
      :sys.get_state(socket.channel_pid)

      # Confirm prompt is queued
      channel_state = :sys.get_state(socket.channel_pid)
      assert channel_state.assigns[:queued_prompt] != nil

      # Fail the MCP init
      error_response = %{
        "jsonrpc" => "2.0",
        "id" => init_request_id,
        "error" => %{
          "code" => -32_603,
          "message" => "MCP server crashed"
        }
      }

      push(socket, "mcp:message", error_response)
      :sys.get_state(socket.channel_pid)

      # The queued prompt should have been processed after MCP failure
      channel_state = :sys.get_state(socket.channel_pid)
      assert channel_state.assigns[:queued_prompt] == nil
      assert channel_state.assigns.mcp_status == :failed
    end
  end

  # ---------------------------------------------------------------------------
  # MEDIUM: Invalid ACP message with id field
  # ---------------------------------------------------------------------------

  describe "invalid ACP message handling" do
    import ExUnit.CaptureLog

    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "sends error response for invalid ACP message with id", %{socket: socket} do
      # Send a payload that fails JsonRpc.parse but has an "id" field
      log =
        capture_log(fn ->
          push(socket, "acp:message", %{
            "id" => 999,
            "method" => "session/prompt"
            # Missing "jsonrpc" => "2.0"
          })

          :sys.get_state(socket.channel_pid)

          assert_push("acp:message", %{
            "jsonrpc" => "2.0",
            "id" => 999,
            "error" => %{
              "code" => -32_600,
              "message" => "Invalid JSON-RPC message"
            }
          })
        end)

      assert log =~ "Invalid ACP message"
    end

    test "silently handles invalid ACP message without id", %{socket: socket} do
      capture_log(fn ->
        push(socket, "acp:message", %{
          "method" => "session/prompt"
          # Missing "jsonrpc" and no "id"
        })

        :sys.get_state(socket.channel_pid)

        # No error response should be pushed (no id to respond to)
        refute_push("acp:message", %{"error" => _})
      end)

      assert Process.alive?(socket.channel_pid)
    end

    test "handles ACP notification for unknown method without crashing", %{socket: socket} do
      push(socket, "acp:message", %{
        "jsonrpc" => "2.0",
        "method" => "unknown/notification",
        "params" => %{}
      })

      :sys.get_state(socket.channel_pid)

      # Notifications have no id, so no response expected
      refute_push("acp:message", %{"error" => _})
      assert Process.alive?(socket.channel_pid)
    end
  end

  # ---------------------------------------------------------------------------
  # MEDIUM: MCP response for unknown request_id
  # ---------------------------------------------------------------------------

  describe "MCP response for unknown request" do
    import ExUnit.CaptureLog

    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "logs warning for success response with unknown id", %{socket: socket} do
      log =
        capture_log(fn ->
          push(
            socket,
            "mcp:message",
            JsonRpc.success_response(999_999, %{"data" => "stale"})
          )

          :sys.get_state(socket.channel_pid)
        end)

      assert log =~ "unknown request_id"
      assert Process.alive?(socket.channel_pid)
    end

    test "logs warning for error response with unknown id", %{socket: socket} do
      log =
        capture_log(fn ->
          push(socket, "mcp:message", %{
            "jsonrpc" => "2.0",
            "id" => 999_999,
            "error" => %{"code" => -32_000, "message" => "Unknown"}
          })

          :sys.get_state(socket.channel_pid)
        end)

      assert log =~ "unknown request_id"
      assert Process.alive?(socket.channel_pid)
    end
  end

  # ---------------------------------------------------------------------------
  # LOW: Unhandled message crash
  # ---------------------------------------------------------------------------

  describe "unhandled message" do
    setup %{scope: scope} do
      {socket, task_id} = join_task_channel(scope)
      complete_mcp_handshake(socket)
      {:ok, socket: socket, task_id: task_id}
    end

    test "raises on unexpected message", %{socket: socket} do
      # Trap exits so the linked channel crash doesn't take down the test process
      Process.flag(:trap_exit, true)

      ref = Process.monitor(socket.channel_pid)

      send(socket.channel_pid, {:completely_unexpected_message, "surprise"})

      assert_receive {:DOWN, ^ref, :process, _, _reason}
    end
  end
end
