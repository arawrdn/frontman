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
    FrontmanServer.Tools.TodoRemove,
    FrontmanServer.Tools.Question
  ]

  @todo_mutations ["todo_add", "todo_update", "todo_remove"]

  # Interactive backend tools suspend execution and await user input via
  # ACP elicitation. They are defined server-side (so the LLM sees them)
  # but never executed by ToolExecutor — the TaskChannel handles the
  # elicitation flow instead.
  @interactive_tools ["question"]

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

  - `:backend` — synchronous backend tools executed by ToolExecutor
  - `:interactive` — backend tools that suspend and await user input via ACP elicitation
  - `:mcp` — browser-side tools routed to the MCP client
  """
  @spec execution_target(String.t()) :: :backend | :interactive | :mcp
  def execution_target(tool_name) do
    case find_tool(tool_name) do
      {:ok, _module} ->
        if interactive?(tool_name), do: :interactive, else: :backend

      :not_found ->
        :mcp
    end
  end

  @doc "Returns true if the tool is an interactive backend tool (e.g. question)."
  @spec interactive?(String.t()) :: boolean()
  def interactive?(tool_name), do: tool_name in @interactive_tools

  @spec todo_mutation?(String.t()) :: boolean()
  def todo_mutation?(tool_name), do: tool_name in @todo_mutations

  @doc """
  Returns whether a tool call should be tracked in pending MCP requests.

  Interactive tools (both backend and MCP) don't get tracked in the MCP
  pending requests map because they are handled via ACP `session/elicitation`
  instead — the response arrives as a JSON-RPC response on the ACP channel.
  """
  @spec track_pending?([MCP.t()], String.t()) :: boolean()
  def track_pending?(mcp_tool_defs, tool_name) do
    not interactive?(tool_name) and not MCP.interactive_by_name?(mcp_tool_defs, tool_name)
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
