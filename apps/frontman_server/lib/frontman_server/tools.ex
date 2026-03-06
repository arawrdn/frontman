defmodule FrontmanServer.Tools do
  @moduledoc """
  Backend tool aggregator.
  """

  alias FrontmanServer.Tools.Backend
  alias FrontmanServer.Tools.MCP

  @backend_tools [
    FrontmanServer.Tools.TodoList,
    FrontmanServer.Tools.TodoAdd,
    FrontmanServer.Tools.TodoUpdate,
    FrontmanServer.Tools.TodoRemove
  ]

  @todo_mutations ["todo_add", "todo_update", "todo_remove"]

  @spec backend_tools() :: [SwarmAi.Tool.t()]
  def backend_tools do
    Enum.map(@backend_tools, &Backend.to_swarm_tool/1)
  end

  @spec find_tool(String.t()) :: {:ok, module()} | :not_found
  def find_tool(tool_name) do
    case Enum.find(@backend_tools, fn mod -> mod.name() == tool_name end) do
      nil -> :not_found
      mod -> {:ok, mod}
    end
  end

  @doc """
  Returns the execution target for a tool.

  Backend tools are executed server-side by ToolExecutor.
  MCP tools are routed to the browser client for execution.
  """
  @spec execution_target(String.t()) :: :backend | :mcp
  def execution_target(tool_name) do
    case find_tool(tool_name) do
      {:ok, _module} -> :backend
      :not_found -> :mcp
    end
  end

  @spec todo_mutation?(String.t()) :: boolean()
  def todo_mutation?(tool_name), do: tool_name in @todo_mutations

  @doc """
  Returns whether a tool call should be tracked in pending requests.

  Interactive tools (e.g. question) don't get tracked because the client
  returns no MCP response for them — the result arrives via a separate
  channel event (`tool:submit_result`) instead.

  The tool's execution mode is read from the MCP tool definitions,
  which are populated from the wire format during MCP initialization.
  """
  @spec track_pending?([MCP.t()], String.t()) :: boolean()
  def track_pending?(mcp_tool_defs, tool_name) do
    not MCP.interactive_by_name?(mcp_tool_defs, tool_name)
  end

  @doc """
  Prepares all available tools for a task.

  Aggregates backend tools and MCP tools into LLM format.
  MCP tools are passed through the agent execution chain via Backend.Context.

  ## Example
      mcp_tools |> Tools.prepare_for_task(task_id)
  """
  @spec prepare_for_task([FrontmanServer.Tools.MCP.t()], String.t()) :: [SwarmAi.Tool.t()]
  def prepare_for_task(mcp_tools, _task_id) do
    mcp_formatted = MCP.to_swarm_tools(mcp_tools)
    backend = backend_tools()

    backend ++ mcp_formatted
  end
end
