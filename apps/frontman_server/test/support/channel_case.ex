defmodule FrontmanServerWeb.ChannelCase do
  @moduledoc """
  This module defines the test case to be used by
  channel tests.

  Such tests rely on `Phoenix.ChannelTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use FrontmanServerWeb.ChannelCase, async: true`,
  although this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  alias Ecto.Adapters.SQL.Sandbox
  alias FrontmanServer.Accounts
  alias FrontmanServer.Accounts.Scope
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tasks.Interaction
  alias FrontmanServerWeb.UserSocket

  using do
    quote do
      # Import conveniences for testing with channels
      import Phoenix.ChannelTest
      import FrontmanServerWeb.ChannelCase

      # The default endpoint for testing
      @endpoint FrontmanServerWeb.Endpoint
    end
  end

  setup tags do
    if tags[:shared_sandbox] && tags[:async] do
      raise "Cannot combine shared_sandbox: true with async: true - shared sandbox requires synchronous execution"
    end

    shared = tags[:shared_sandbox] || not tags[:async]
    pid = Sandbox.start_owner!(FrontmanServer.Repo, shared: shared)
    on_exit(fn -> Sandbox.stop_owner(pid) end)

    # Create a test user for scope
    {:ok, user} =
      Accounts.register_user(%{
        email: "channel_test_#{System.unique_integer([:positive])}@test.local",
        name: "Test User",
        password: "testpassword123!"
      })

    scope = Scope.for_user(user)
    {:ok, scope: scope, user: user}
  end

  # ---------------------------------------------------------------------------
  # Task + Socket Setup Helpers
  # ---------------------------------------------------------------------------

  @doc """
  Creates a task and joins the task channel, returning `{socket, task_id}`.

  Options:
    - `:framework` - framework string (default: `"nextjs"`)
  """
  def join_task_channel(scope, opts \\ []) do
    framework = Keyword.get(opts, :framework, "nextjs")
    task_id = Ecto.UUID.generate()
    {:ok, ^task_id} = Tasks.create_task(scope, task_id, framework)

    sock =
      Phoenix.ChannelTest.__socket__(
        UserSocket,
        "user_id",
        %{scope: scope},
        FrontmanServerWeb.Endpoint,
        []
      )

    {:ok, _reply, socket} =
      Phoenix.ChannelTest.subscribe_and_join(sock, "task:#{task_id}", %{})

    {socket, task_id}
  end

  # ---------------------------------------------------------------------------
  # MCP Handshake Helpers
  #
  # These simulate the multi-step MCP initialization sequence that the channel
  # performs on join: initialize → initialized → tools/list →
  # load_agent_instructions → list_tree → mcp_initialization_complete.
  #
  # Uses :sys.get_state/1 as a synchronization barrier after each push to
  # ensure the channel process has fully processed the message before we
  # assert the next response. Without these barriers, under CI load
  # (especially coverage runs), assert_push can time out.
  # ---------------------------------------------------------------------------

  @doc """
  Completes the MCP handshake with no tools registered.
  """
  def complete_mcp_handshake(socket) do
    do_mcp_handshake(socket, %{"tools" => []})
  end

  @doc """
  Completes the MCP handshake with the given tools list result.

  Example:

      tools = %{
        "tools" => [
          %{"name" => "get_logs", "description" => "...", "inputSchema" => %{...}}
        ]
      }
      complete_mcp_handshake_with_tools(socket, tools)
  """
  def complete_mcp_handshake_with_tools(socket, tools_result) do
    do_mcp_handshake(socket, tools_result)
  end

  defp do_mcp_handshake(socket, tools_result) do
    :sys.get_state(socket.channel_pid)

    init_request_id = assert_mcp_push("initialize")

    init_result = %{
      "protocolVersion" => ModelContextProtocol.protocol_version(),
      "capabilities" => %{"tools" => %{}},
      "serverInfo" => %{"name" => "test-mcp", "version" => "1.0.0"}
    }

    Phoenix.ChannelTest.push(
      socket,
      "mcp:message",
      JsonRpc.success_response(init_request_id, init_result)
    )

    :sys.get_state(socket.channel_pid)

    assert_receive %Phoenix.Socket.Message{
      event: "mcp:message",
      payload: %{"method" => "notifications/initialized"}
    }

    tools_request_id = assert_mcp_push("tools/list")

    Phoenix.ChannelTest.push(
      socket,
      "mcp:message",
      JsonRpc.success_response(tools_request_id, tools_result)
    )

    :sys.get_state(socket.channel_pid)

    project_rules_request_id = assert_mcp_tool_call("load_agent_instructions")

    Phoenix.ChannelTest.push(
      socket,
      "mcp:message",
      JsonRpc.success_response(project_rules_request_id, %{"content" => []})
    )

    :sys.get_state(socket.channel_pid)

    project_structure_request_id = assert_mcp_tool_call("list_tree")

    Phoenix.ChannelTest.push(
      socket,
      "mcp:message",
      JsonRpc.success_response(project_structure_request_id, %{"content" => []})
    )

    :sys.get_state(socket.channel_pid)

    assert_receive %Phoenix.Socket.Message{
      event: "acp:message",
      payload: %{"method" => "mcp_initialization_complete"}
    }
  end

  # Asserts an MCP method push was received and returns its request id.
  defp assert_mcp_push(method) do
    assert_receive %Phoenix.Socket.Message{
      event: "mcp:message",
      payload: %{"id" => id, "method" => ^method}
    }

    id
  end

  # Asserts an MCP tools/call push was received for the given tool name
  # and returns its request id.
  defp assert_mcp_tool_call(tool_name) do
    assert_receive %Phoenix.Socket.Message{
      event: "mcp:message",
      payload: %{
        "id" => id,
        "method" => "tools/call",
        "params" => %{"name" => ^tool_name}
      }
    }

    id
  end

  # ---------------------------------------------------------------------------
  # Fixture Builders
  # ---------------------------------------------------------------------------

  @doc """
  Builds an `Interaction.ToolCall` struct with sensible defaults.
  Override any field via the opts keyword list.

  Example:

      tool_call = build_tool_call(tool_name: "consoleLog", arguments: %{"msg" => "hi"})
  """
  def build_tool_call(opts \\ []) do
    %Interaction.ToolCall{
      id: Keyword.get(opts, :id, Interaction.new_id()),
      sequence: Keyword.get(opts, :sequence, Interaction.new_sequence()),
      tool_call_id: Keyword.get(opts, :tool_call_id, "call_#{:rand.uniform(1_000_000)}"),
      tool_name: Keyword.get(opts, :tool_name, "testTool"),
      arguments: Keyword.get(opts, :arguments, %{}),
      timestamp: Keyword.get(opts, :timestamp, Interaction.now())
    }
  end

  @doc """
  Builds an `Interaction.ToolResult` struct with sensible defaults.
  """
  def build_tool_result(opts \\ []) do
    %Interaction.ToolResult{
      id: Keyword.get(opts, :id, Interaction.new_id()),
      sequence: Keyword.get(opts, :sequence, Interaction.new_sequence()),
      tool_call_id: Keyword.get(opts, :tool_call_id, "call_#{:rand.uniform(1_000_000)}"),
      tool_name: Keyword.get(opts, :tool_name, "testTool"),
      result: Keyword.get(opts, :result, "ok"),
      is_error: Keyword.get(opts, :is_error, false),
      timestamp: Keyword.get(opts, :timestamp, Interaction.now())
    }
  end

  @doc """
  Builds an ACP `session/prompt` JSON-RPC request map.
  """
  def build_prompt_request(id, text) do
    %{
      "jsonrpc" => "2.0",
      "id" => id,
      "method" => "session/prompt",
      "params" => %{
        "prompt" => %{
          "messages" => [
            %{
              "role" => "user",
              "content" => %{"type" => "text", "text" => text}
            }
          ]
        }
      }
    }
  end

  @doc """
  Builds a generic ACP JSON-RPC request map.
  """
  def build_acp_request(id, method, params \\ %{}) do
    %{"jsonrpc" => "2.0", "id" => id, "method" => method, "params" => params}
  end
end
