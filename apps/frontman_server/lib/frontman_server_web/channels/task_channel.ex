defmodule FrontmanServerWeb.TaskChannel do
  @moduledoc """
  Channel for task-specific ACP events.

  Clients join this channel after creating a task via the
  tasks channel. Handles prompt messages and streams
  agent responses back to the client.
  """
  use FrontmanServerWeb, :channel
  require Logger

  alias AgentClientProtocol, as: ACP
  alias FrontmanServer.Tasks
  alias FrontmanServer.Tools
  alias FrontmanServerWeb.ACPHistory
  alias FrontmanServerWeb.TaskChannel.MCPInitializer
  alias ModelContextProtocol, as: MCP

  @impl true
  def join("task:" <> task_id, _params, socket) do
    scope = socket.assigns.scope

    case Tasks.get_task(scope, task_id) do
      {:ok, _task} ->
        Logger.info("Client joining: #{task_id}, socket_id: #{inspect(self())}")

        # Start MCP initialization as a synchronous state machine.
        # State is stored in socket assigns — no separate GenServer process.
        # Each websocket connection needs its own MCP session because:
        # 1. MCPInitializer performs a stateful handshake with the browser-side MCP client
        # 2. Project rules loading depends on client-specific context
        # Tools are stored in socket assigns and passed through Backend.Context for agent access.
        #
        # Note: Phoenix channels prohibit push() during join/3, so we defer
        # the initial MCP request push to handle_info(:start_mcp_init).
        # All subsequent MCP responses are processed synchronously in handle_in.
        {init_state, init_actions} = MCPInitializer.start(task_id, scope)

        socket =
          socket
          |> assign(:task_id, task_id)
          |> assign(:mcp_init_state, init_state)
          |> assign(:mcp_status, :pending)
          |> assign(:mcp_init_actions, init_actions)
          |> assign(:pending_requests, %{})
          |> assign(:announced_tool_calls, MapSet.new())
          |> assign(:last_execution_tools, [])
          |> assign(:last_execution_opts, [])

        send(self(), :start_mcp_init)

        {:ok, %{task_id: task_id}, socket}

      {:error, :not_found} ->
        Logger.warning("Client tried to join non-existent task: #{task_id}")
        {:error, %{reason: "task_not_found"}}
    end
  end

  @impl true
  def handle_in("acp:message", payload, socket) do
    case JsonRpc.parse(payload) do
      {:ok, {:request, request_id, "session/prompt", params}} ->
        handle_prompt(request_id, params, socket)

      {:ok, {:notification, "session/cancel", params}} ->
        handle_cancel(params, socket)

      {:ok, {:request, request_id, "session/load", params}} ->
        # Load session history - streamed via session/update notifications
        handle_session_load(request_id, params, socket)

      {:ok, {:request, request_id, method, _params}} ->
        Logger.error("Unknown ACP method in task channel: #{method}")

        response =
          JsonRpc.error_response(
            request_id,
            JsonRpc.error_method_not_found(),
            "Method not found: #{method}"
          )

        {:reply, {:ok, %{"acp:message" => response}}, socket}

      {:ok, {:notification, _method, _params}} ->
        {:noreply, socket}

      {:error, _reason} ->
        # Not a request/notification — try parsing as a JSON-RPC response.
        # The client sends responses on the ACP channel for elicitation requests.
        case JsonRpc.parse_response(payload) do
          {:ok, {:success, tool_call_id, result}} ->
            handle_acp_response(tool_call_id, result, socket)

          {:ok, {:error, tool_call_id, error}} ->
            handle_acp_response_error(tool_call_id, error, socket)

          {:error, reason} ->
            Logger.error(
              "Invalid ACP message in task channel: #{inspect(reason)}, payload: #{inspect(payload)}"
            )

            # If payload has an id, send error response
            case payload do
              %{"id" => request_id} ->
                error_response =
                  JsonRpc.error_response(
                    request_id,
                    JsonRpc.error_invalid_request(),
                    "Invalid JSON-RPC message"
                  )

                push(socket, "acp:message", error_response)
                {:noreply, socket}

              _ ->
                {:noreply, socket}
            end
        end
    end
  end

  @impl true
  def handle_in("mcp:message", payload, socket) do
    Logger.debug("Received mcp:message payload: #{inspect(payload)}")

    case JsonRpc.parse_response(payload) do
      {:ok, {:success, request_id, result}} ->
        handle_mcp_response(request_id, result, socket)

      {:ok, {:error, request_id, error}} ->
        handle_mcp_error(request_id, error, socket)

      {:error, reason} ->
        Logger.error("Invalid MCP response: #{inspect(reason)}, payload: #{inspect(payload)}")

        # Send error notification to client for better debugging
        error_notification =
          JsonRpc.notification("error", %{
            "message" => "Invalid JSON-RPC response",
            "reason" => Atom.to_string(reason)
          })

        push(socket, "mcp:message", error_notification)

        {:noreply, socket}
    end
  end

  defp handle_mcp_response(request_id, result, socket) do
    pending_requests = socket.assigns.pending_requests
    init_state = socket.assigns[:mcp_init_state]

    Logger.debug(
      "MCP response received: request_id=#{request_id}, pending_keys=#{inspect(Map.keys(pending_requests))}"
    )

    cond do
      # Tool call response - channel owns these IDs
      Map.has_key?(pending_requests, request_id) ->
        Logger.debug("MCP response #{request_id} matched pending tool call")

        case Map.pop(pending_requests, request_id) do
          {{:tool_call, tool_call}, remaining_requests} ->
            handle_tool_call_response(request_id, tool_call, result, socket, remaining_requests)

          {nil, _} ->
            Logger.warning("Received MCP response for unknown request_id: #{request_id}")
            {:noreply, socket}
        end

      # Initialization response - MCPInitializer state owns these IDs
      init_state && MCPInitializer.expects_response?(init_state, request_id) ->
        Logger.debug("MCP response #{request_id} matched MCPInitializer")
        {new_state, actions} = MCPInitializer.handle_response(init_state, request_id, result)
        socket = assign(socket, :mcp_init_state, new_state)
        socket = execute_init_actions(actions, socket)
        maybe_process_queued_prompt(socket)

      true ->
        Logger.warning("Received MCP response for unknown request_id: #{request_id}")
        {:noreply, socket}
    end
  end

  defp handle_tool_call_response(_request_id, tool_call, result, socket, remaining_requests) do
    task_id = socket.assigns.task_id
    text_result = MCP.extract_content_text(result)
    parsed_result = MCP.parse_tool_result(text_result)
    is_error = MCP.error?(result)

    status =
      if is_error, do: ACP.tool_call_status_failed(), else: ACP.tool_call_status_completed()

    Logger.info("MCP tool #{tool_call.tool_name} #{status}: #{text_result}")

    # Send ACP notification with appropriate status
    notification =
      ACP.tool_call_update(
        task_id,
        tool_call.tool_call_id,
        status,
        ACP.Content.from_tool_result(text_result)
      )

    push(socket, "acp:message", notification)

    # Store result and notify agent (use parsed result to preserve structured data like screenshots)
    Tasks.add_tool_result(
      socket.assigns.scope,
      task_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      parsed_result,
      is_error
    )

    # Resume execution if the agent suspended waiting for this tool result.
    tools = socket.assigns.last_execution_tools
    opts = socket.assigns.last_execution_opts
    Tasks.maybe_resume_after_tool_result(socket.assigns.scope, task_id, tools, opts)

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
  end

  defp handle_mcp_error(request_id, error, socket) do
    pending_requests = socket.assigns.pending_requests
    init_state = socket.assigns[:mcp_init_state]

    Logger.debug(
      "MCP error received: request_id=#{request_id}, pending_keys=#{inspect(Map.keys(pending_requests))}"
    )

    cond do
      # Tool call error - channel owns these IDs
      Map.has_key?(pending_requests, request_id) ->
        case Map.pop(pending_requests, request_id) do
          {{:tool_call, tool_call}, remaining_requests} ->
            handle_tool_call_error(request_id, tool_call, error, socket, remaining_requests)

          {nil, _} ->
            Logger.warning("Received MCP error for unknown request_id: #{request_id}")
            {:noreply, socket}
        end

      # Initialization error - MCPInitializer state owns these IDs
      init_state && MCPInitializer.expects_response?(init_state, request_id) ->
        {new_state, actions} = MCPInitializer.handle_error(init_state, request_id, error)
        socket = assign(socket, :mcp_init_state, new_state)
        socket = execute_init_actions(actions, socket)
        maybe_process_queued_prompt(socket)

      true ->
        Logger.warning("Received MCP error for unknown request_id: #{request_id}")
        {:noreply, socket}
    end
  end

  defp handle_tool_call_error(_request_id, tool_call, error, socket, remaining_requests) do
    task_id = socket.assigns.task_id
    error_message = error["message"] || "Unknown MCP error"
    Logger.error("MCP tool #{tool_call.tool_name} failed: #{error_message}")

    Sentry.capture_message("MCP tool execution failed",
      level: :error,
      tags: %{error_type: "mcp_tool_error"},
      extra: %{
        tool_name: tool_call.tool_name,
        tool_call_id: tool_call.tool_call_id,
        task_id: task_id,
        error_message: error_message
      }
    )

    # Send ACP notification: failed
    failed_notification =
      ACP.tool_call_update(
        task_id,
        tool_call.tool_call_id,
        ACP.tool_call_status_failed(),
        ACP.Content.from_tool_result(error_message)
      )

    push(socket, "acp:message", failed_notification)

    # Store error result and notify agent
    Tasks.add_tool_result(
      socket.assigns.scope,
      task_id,
      %{id: tool_call.tool_call_id, name: tool_call.tool_name},
      error_message,
      true
    )

    socket = assign(socket, :pending_requests, remaining_requests)
    {:noreply, socket}
  end

  defp handle_prompt(request_id, params, socket) do
    task_id = socket.assigns.task_id

    # Check if MCP initialization is complete
    case socket.assigns[:mcp_status] do
      :ready ->
        # MCP is ready, process the prompt immediately
        process_prompt(request_id, params, socket)

      :failed ->
        # MCP failed, process anyway with empty tools (best effort)
        Logger.warning("Processing prompt with failed MCP initialization for task #{task_id}")
        process_prompt(request_id, params, socket)

      _pending ->
        # MCP still initializing, queue the prompt
        Logger.info("MCP still initializing, queueing prompt for task #{task_id}")

        socket =
          socket
          |> assign(:queued_prompt, {request_id, params})

        {:noreply, socket}
    end
  end

  # ACP spec: session/cancel is a NOTIFICATION (no response expected).
  # The pending session/prompt request will be resolved with stopReason: "cancelled"
  # via the :agent_cancelled handler (triggered by ExecutionMonitor).
  defp handle_cancel(_params, socket) do
    task_id = socket.assigns.task_id
    Logger.info("Cancel notification received for task #{task_id}")

    case Tasks.cancel_execution(socket.assigns.scope, task_id) do
      :ok ->
        Logger.info("Agent cancel signal sent for task #{task_id}")

      {:error, :not_running} ->
        Logger.info("Cancel notification for task #{task_id}: no agent running")
    end

    {:noreply, socket}
  end

  # Handle a JSON-RPC response (success or error) on the ACP channel.
  #
  # The response `id` is the tool_call_id we used as the JSON-RPC request `id`.
  # We look up the original ToolCall interaction from the DB to recover the
  # tool_name and questions — no in-memory pending map needed.
  #
  # Persist-first ordering: the tool result is written before the client is
  # notified, fixing the race condition from Devin's review comment #2.
  defp handle_acp_response(tool_call_id, result, socket) do
    task_id = socket.assigns.task_id

    case Tasks.find_tool_call(task_id, tool_call_id) do
      {:ok, tool_call} ->
        %{"questions" => questions} = tool_call.arguments
        {action, content} = ACP.parse_elicitation_response(result)

        Logger.info(
          "Elicitation response for #{tool_call.tool_name} (#{tool_call_id}): action=#{action}"
        )

        tool_output = ACP.elicitation_content_to_tool_output(action, content, questions)
        persist_and_resume(tool_call_id, tool_call.tool_name, tool_output, socket)

      {:error, :not_found} ->
        Logger.warning(
          "ACP response for unknown tool_call_id: #{tool_call_id} on task #{task_id}"
        )

        push(
          socket,
          "acp:message",
          ACP.build_error_notification(
            task_id,
            "Response rejected: unknown tool_call_id #{tool_call_id}"
          )
        )

        {:noreply, socket}
    end
  end

  # Handle a JSON-RPC error response — treat as cancellation.
  defp handle_acp_response_error(tool_call_id, error, socket) do
    task_id = socket.assigns.task_id

    case Tasks.find_tool_call(task_id, tool_call_id) do
      {:ok, tool_call} ->
        Logger.error(
          "Elicitation error for #{tool_call.tool_name} (#{tool_call_id}): " <>
            (error["message"] || "unknown")
        )

        tool_output = %{"answers" => [], "skippedAll" => false, "cancelled" => true}
        persist_and_resume(tool_call_id, tool_call.tool_name, tool_output, socket)

      {:error, :not_found} ->
        Logger.warning(
          "ACP error response for unknown tool_call_id: #{tool_call_id} on task #{task_id}"
        )

        push(
          socket,
          "acp:message",
          ACP.build_error_notification(
            task_id,
            "Error response rejected: unknown tool_call_id #{tool_call_id}"
          )
        )

        {:noreply, socket}
    end
  end

  # Persist a tool result, notify the client, and resume agent execution.
  defp persist_and_resume(tool_call_id, tool_name, tool_output, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    result_json = Jason.encode!(tool_output)

    Tasks.add_tool_result(
      scope,
      task_id,
      %{id: tool_call_id, name: tool_name},
      result_json,
      false
    )

    notification =
      ACP.tool_call_update(
        task_id,
        tool_call_id,
        ACP.tool_call_status_completed(),
        ACP.Content.from_tool_result(result_json)
      )

    push(socket, "acp:message", notification)

    tools = socket.assigns.last_execution_tools
    opts = socket.assigns.last_execution_opts
    Tasks.maybe_resume_after_tool_result(scope, task_id, tools, opts)

    {:noreply, socket}
  end

  # Handle session/load - stream history via session/update notifications
  # This is called after the client has joined the session channel, allowing
  # history notifications to be received through the onUpdate callback.
  #
  # Also populates last_execution_opts/tools from metadata so that resuming
  # a suspended agent after reconnect has valid execution context (model,
  # env_api_key, tools). Without this, answering a pending elicitation after
  # page refresh would fail with "No API key available for this request."
  defp handle_session_load(request_id, params, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    Logger.info("ACP session/load request received on session channel for: #{task_id}")

    case Tasks.get_task(scope, task_id) do
      {:ok, task} ->
        # Populate execution context from client metadata (same fields as session/prompt)
        socket = populate_execution_context(params, socket)

        # Stream history via session/update notifications
        stream_session_history(socket, task)

        # Re-send elicitation for any unanswered question tool calls
        resend_pending_elicitations(socket, task)

        # Return ACP-compliant response
        push(socket, "acp:message", JsonRpc.success_response(request_id, %{}))
        {:noreply, socket}

      {:error, :not_found} ->
        push(
          socket,
          "acp:message",
          JsonRpc.error_response(request_id, JsonRpc.error_invalid_params(), "Session not found")
        )

        {:noreply, socket}
    end
  end

  # Extracts env_api_key, model, and tools from session/load (or session/prompt)
  # metadata and stores them in socket assigns for agent resume.
  defp populate_execution_context(params, socket) do
    task_id = socket.assigns.task_id
    mcp_tools = socket.assigns[:mcp_tools] || []

    metadata = params["metadata"] || %{}
    env_api_key = ACP.extract_env_api_key(metadata)
    model = ACP.extract_model(metadata)

    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)
    opts = [env_api_key: env_api_key, model: model, mcp_tool_defs: mcp_tools]

    socket
    |> assign(:last_execution_tools, all_tools)
    |> assign(:last_execution_opts, opts)
  end

  # Streams session history as ACP session/update notifications
  defp stream_session_history(socket, task) do
    task.interactions
    |> Enum.flat_map(&ACPHistory.to_history_items(&1, task.task_id))
    |> Enum.each(fn notification ->
      push(socket, "acp:message", notification)
    end)
  end

  # After streaming history, re-send elicitation requests for any question
  # tool calls that don't have a matching ToolResult (e.g. page reload while
  # a question was pending). The response handler does a DB lookup, so no
  # in-memory tracking is needed here.
  defp resend_pending_elicitations(socket, task) do
    answered_ids =
      task.interactions
      |> Enum.filter(&match?(%Tasks.Interaction.ToolResult{}, &1))
      |> MapSet.new(& &1.tool_call_id)

    task.interactions
    |> Enum.filter(fn
      %Tasks.Interaction.ToolCall{tool_name: "question", tool_call_id: tool_call_id} ->
        not MapSet.member?(answered_ids, tool_call_id)

      _ ->
        false
    end)
    |> Enum.each(&push_elicitation(&1, task.task_id, socket))
  end

  defp process_prompt(request_id, params, socket) do
    task_id = socket.assigns.task_id
    scope = socket.assigns.scope
    mcp_tools = socket.assigns.mcp_tools

    # Extract env API key and model selection from prompt metadata
    metadata = params["metadata"] || %{}
    env_api_key = ACP.extract_env_api_key(metadata)
    model = ACP.extract_model(metadata)

    # Parse ACP prompt (protocol layer)
    prompt = ACP.parse_prompt_params(params)

    # Logging
    Logger.info("Received prompt for task", %{
      task_id: task_id,
      text_summary: prompt.text_summary,
      has_resources: prompt.has_resources,
      model: model
    })

    all_tools = mcp_tools |> Tools.prepare_for_task(task_id)

    # Track request ID (channel state)
    socket = assign(socket, :pending_prompt_id, request_id)

    # Pass env_api_key, model, and MCP tool definitions to the agent through opts.
    # mcp_tool_defs carries execution_mode so the executor knows which tools are interactive.
    opts = [env_api_key: env_api_key, model: model, mcp_tool_defs: mcp_tools]

    case Tasks.add_user_message(scope, task_id, prompt.content, all_tools, opts) do
      {:ok, _interaction} ->
        Logger.info("User message added, agent spawned for task #{task_id}")

        # Store execution context for potential resume after interactive tool suspension
        socket =
          socket
          |> assign(:last_execution_tools, all_tools)
          |> assign(:last_execution_opts, opts)

        # Generate title asynchronously on first user message.
        # The socket assign guards against concurrent calls if a second prompt
        # arrives before the async title generation persists to the DB.
        socket =
          if socket.assigns[:title_generation_started] do
            socket
          else
            Tasks.maybe_generate_title(scope, task_id, prompt.text_summary, model, env_api_key)
            assign(socket, :title_generation_started, true)
          end

        {:noreply, socket}

      {:error, reason} ->
        Logger.error("Failed to add user message: #{inspect(reason)}")
        error_response = JsonRpc.error_response(request_id, -32_000, to_string(reason))
        {:reply, {:ok, %{"acp:message" => error_response}}, socket}
    end
  end

  @impl true
  def handle_info(:start_mcp_init, socket) do
    # Deferred from join/3 because Phoenix channels prohibit push() during join.
    # The init state and actions were already created in join — we just need
    # to execute the deferred push actions now that the socket is fully joined.
    actions = socket.assigns.mcp_init_actions
    socket = assign(socket, :mcp_init_actions, nil)
    socket = execute_init_actions(actions, socket)
    {:noreply, socket}
  end

  def handle_info({:stream_token, text}, socket) do
    # Translate domain event to ACP notification
    # ACP compliant: agent_message_chunk implicitly signals message start
    Logger.debug("Channel received stream_token: #{byte_size(text)} bytes, text=#{inspect(text)}")

    task_id = socket.assigns.task_id
    notification = ACP.build_agent_message_chunk_notification(task_id, text)
    Logger.debug("Pushing notification: #{inspect(notification)}")
    push(socket, "acp:message", notification)
    {:noreply, socket}
  end

  def handle_info({:stream_thinking, _text}, socket) do
    # Thinking tokens not forwarded to client yet - client infers thinking state from message status
    # Broadcast kept in agents.ex for future implementation of visible thinking
    {:noreply, socket}
  end

  def handle_info(:agent_completed, socket) do
    Logger.debug(
      "Channel received agent_completed, pending_prompt_id=#{inspect(socket.assigns[:pending_prompt_id])}"
    )

    handle_turn_ended(socket, "end_turn")
  end

  def handle_info(:agent_suspended, socket) do
    Logger.info(
      "Channel received agent_suspended for task #{socket.assigns.task_id} (waiting for user input)"
    )

    {:noreply, socket}
  end

  def handle_info(:agent_cancelled, socket) do
    Logger.info("Channel received agent_cancelled for task #{socket.assigns.task_id}")

    handle_turn_ended(socket, "cancelled")
  end

  def handle_info({:tool_call_start, tool_call_id, tool_name}, socket) do
    # Early notification: the LLM has started generating a tool call.
    # This fires as soon as the tool_call_start chunk arrives from the LLM stream,
    # BEFORE the full arguments are generated. For tools with large arguments
    # (e.g., write_file with full file content), this provides immediate UI feedback
    # instead of waiting for the entire response to be accumulated.
    task_id = socket.assigns.task_id

    notification =
      ACP.tool_call_create(
        task_id,
        tool_call_id,
        tool_name,
        "other",
        ACP.tool_call_status_pending()
      )

    push(socket, "acp:message", notification)

    # Track that we already announced this tool call to avoid duplicate notifications
    announced = socket.assigns.announced_tool_calls
    socket = assign(socket, :announced_tool_calls, MapSet.put(announced, tool_call_id))

    {:noreply, socket}
  end

  def handle_info({:interaction, %Tasks.Interaction.ToolCall{} = tool_call}, socket) do
    task_id = socket.assigns.task_id

    # Only send tool_call_create if we haven't already announced this tool call
    # via the streaming :tool_call_start event (which fires earlier during LLM streaming).
    if !(socket.assigns.announced_tool_calls |> MapSet.member?(tool_call.tool_call_id)) do
      pending_notification =
        ACP.tool_call_create(
          task_id,
          tool_call.tool_call_id,
          tool_call.tool_name,
          "other",
          ACP.tool_call_status_pending()
        )

      push(socket, "acp:message", pending_notification)
    end

    # Always send tool arguments so the UI can display them
    args_content = ACP.Content.from_tool_result(tool_call.arguments)

    args_notification =
      ACP.tool_call_update(
        task_id,
        tool_call.tool_call_id,
        ACP.tool_call_status_pending(),
        args_content
      )

    push(socket, "acp:message", args_notification)

    case Tools.execution_target(tool_call.tool_name) do
      :backend ->
        # Backend tools are executed by ToolExecutor in the agent loop.
        # The channel just notifies the UI (already done above).
        # When the tool completes, we'll receive a ToolResult notification.
        {:noreply, socket}

      :interactive ->
        # Interactive backend tool (e.g. question) → send session/elicitation
        # request on ACP channel. The ToolExecutor already returned :suspended.
        send_elicitation_for_tool_call(tool_call, socket)

      :mcp ->
        mcp_tool_defs = socket.assigns[:mcp_tools] || []

        if Tools.MCP.interactive_by_name?(mcp_tool_defs, tool_call.tool_name) do
          # Interactive MCP tool → send session/elicitation request on ACP channel
          send_elicitation_for_tool_call(tool_call, socket)
        else
          # Regular MCP tool → route to browser MCP client
          route_to_mcp(tool_call, socket)
        end
    end
  end

  def handle_info({:interaction, %Tasks.Interaction.ToolResult{} = tool_result}, socket) do
    task_id = socket.assigns.task_id

    # Regular tools: send tool_call_update.
    # Plan/todo-list mutations are handled by {:plan_updated, entries} below.
    unless Tools.todo_mutation?(tool_result.tool_name) do
      status =
        if tool_result.is_error,
          do: ACP.tool_call_status_failed(),
          else: ACP.tool_call_status_completed()

      content = ACP.Content.from_tool_result(tool_result.result)
      notification = ACP.tool_call_update(task_id, tool_result.tool_call_id, status, content)
      push(socket, "acp:message", notification)
    end

    {:noreply, socket}
  end

  def handle_info({:plan_updated, entries}, socket) do
    task_id = socket.assigns.task_id
    push(socket, "acp:message", ACP.plan_update(task_id, entries))
    {:noreply, socket}
  end

  def handle_info({:interaction, _interaction}, socket) do
    # Other interactions don't need transport handling
    {:noreply, socket}
  end

  def handle_info({:agent_error, message}, socket) do
    Logger.error("Agent error: #{message}")

    handle_turn_ended(socket, "error", error_message: message)
  end

  def handle_info(msg, _socket) do
    raise "Unhandled message in TaskChannel: #{inspect(msg)}"
  end

  # Unified handler for all "agent turn ended" domain events.
  #
  # Every turn-ending handler (agent_completed, agent_cancelled, agent_error)
  # delegates here instead of reimplementing the same pending_prompt_id dispatch.
  #
  # The contract:
  #   1. Always push a session/update notification so the client knows the turn
  #      ended — regardless of whether a pending session/prompt RPC exists.
  #   2. If a pending RPC exists, also resolve it (success or error response).
  #   3. Clean up pending_prompt_id.
  #
  # This eliminates the bug class where a nil pending_prompt_id silently
  # drops the turn-ended signal (e.g. after task switch + elicitation response).
  defp handle_turn_ended(socket, stop_reason, opts \\ []) do
    task_id = socket.assigns.task_id
    error_message = Keyword.get(opts, :error_message)

    # 1. Always notify — this is the canonical "turn ended" signal
    notification =
      case error_message do
        nil -> ACP.build_agent_turn_complete_notification(task_id, stop_reason)
        msg -> ACP.build_error_notification(task_id, msg)
      end

    push(socket, "acp:message", notification)

    # 2. If there's a pending RPC, also resolve it
    socket =
      case socket.assigns[:pending_prompt_id] do
        nil ->
          Logger.info("Turn ended (#{stop_reason}) with no pending_prompt_id for task #{task_id}")

          socket

        prompt_id ->
          response =
            case error_message do
              nil -> JsonRpc.success_response(prompt_id, ACP.build_prompt_result(stop_reason))
              msg -> JsonRpc.error_response(prompt_id, -32_000, msg)
            end

          Logger.info("Resolving pending prompt #{prompt_id} with stop_reason=#{stop_reason}")
          push(socket, "acp:message", response)
          assign(socket, :pending_prompt_id, nil)
      end

    {:noreply, socket}
  end

  # Execute actions returned by the MCPInitializer state machine.
  # Each action is processed synchronously within the current callback,
  # eliminating async process hops that caused race conditions.
  defp execute_init_actions(actions, socket) do
    Enum.reduce(actions, socket, fn action, socket ->
      case action do
        {:push_mcp, msg} ->
          push(socket, "mcp:message", msg)
          socket

        {:push_acp, msg} ->
          push(socket, "acp:message", msg)
          socket

        {:initialization_complete, data} ->
          task_id = socket.assigns.task_id
          Logger.info("MCP initialization complete for task #{task_id}")

          socket
          |> assign(:mcp_status, :ready)
          |> assign(:mcp_capabilities, data.mcp_capabilities)
          |> assign(:mcp_server_info, data.mcp_server_info)
          |> assign(:mcp_tools, data.tools)

        {:initialization_failed, error} ->
          Logger.error("MCP initialization failed: #{inspect(error)}")

          socket
          |> assign(:mcp_status, :failed)
          |> assign(:mcp_error, error)
          |> assign(:mcp_tools, [])
      end
    end)
  end

  # Process any queued prompt after MCP initialization completes or fails.
  # Called after execute_init_actions when handling MCP responses.
  #
  # Important: This is called from handle_in("mcp:message", ...), so we must
  # NOT return {:reply, ...} — that would send the reply on the wrong channel
  # event. Any replies from process_prompt are converted to push + {:noreply}.
  defp maybe_process_queued_prompt(socket) do
    case {socket.assigns[:mcp_status], socket.assigns[:queued_prompt]} do
      {:ready, {request_id, params}} ->
        task_id = socket.assigns.task_id
        Logger.info("Processing queued prompt after MCP initialization for task #{task_id}")
        socket = assign(socket, :queued_prompt, nil)
        ensure_noreply(process_prompt(request_id, params, socket), socket)

      {:failed, {request_id, params}} ->
        task_id = socket.assigns.task_id

        Logger.warning(
          "Processing queued prompt with failed MCP initialization for task #{task_id}"
        )

        socket = assign(socket, :queued_prompt, nil)
        ensure_noreply(process_prompt(request_id, params, socket), socket)

      _ ->
        {:noreply, socket}
    end
  end

  # Convert {:reply, ...} tuples to push + {:noreply, ...}.
  # Used when process_prompt is called from a non-ACP context (e.g. after
  # MCP initialization) where {:reply} would send on the wrong channel event.
  defp ensure_noreply({:reply, {:ok, reply_payload}, socket}, _fallback_socket) do
    Enum.each(reply_payload, fn {event, message} ->
      push(socket, event, message)
    end)

    {:noreply, socket}
  end

  defp ensure_noreply({:noreply, socket}, _fallback_socket), do: {:noreply, socket}

  # Send a session/elicitation request for an interactive tool call (e.g. `question`).
  #
  # Uses the tool_call_id as the JSON-RPC request id — the client echoes it
  # back in its response, and we look up the ToolCall from the DB at that point.
  defp send_elicitation_for_tool_call(tool_call, socket) do
    push_elicitation(tool_call, socket.assigns.task_id, socket)
    {:noreply, socket}
  end

  # Builds and pushes a session/elicitation request for a question tool call.
  # Crashes if the tool call arguments don't contain a "questions" key — that
  # means the LLM violated the tool schema and we want to surface it loudly.
  defp push_elicitation(tool_call, task_id, socket) do
    %{"questions" => questions} = tool_call.arguments
    tool_call_id = tool_call.tool_call_id

    schema = ACP.question_to_elicitation_schema(questions)

    request =
      ACP.build_form_elicitation_request(tool_call_id, task_id, "I have some questions", schema)

    Logger.info(
      "Sending session/elicitation for #{tool_call.tool_name} " <>
        "(call_id=#{tool_call_id}) on task #{task_id}"
    )

    push(socket, "acp:message", request)
  end

  defp route_to_mcp(tool_call, socket) do
    task_id = socket.assigns.task_id
    request_id = System.unique_integer([:positive])

    request =
      MCP.tools_call_request(%MCP.ToolCallParams{
        request_id: request_id,
        tool_name: tool_call.tool_name,
        arguments: tool_call.arguments,
        call_id: tool_call.tool_call_id
      })

    # Send ACP notification: in_progress
    in_progress_notification =
      ACP.tool_call_update(
        task_id,
        tool_call.tool_call_id,
        ACP.tool_call_status_in_progress()
      )

    push(socket, "acp:message", in_progress_notification)

    mcp_tool_defs = socket.assigns[:mcp_tools] || []

    socket =
      if Tools.track_pending?(mcp_tool_defs, tool_call.tool_name) do
        pending_requests = socket.assigns.pending_requests

        assign(
          socket,
          :pending_requests,
          Map.put(pending_requests, request_id, {:tool_call, tool_call})
        )
      else
        socket
      end

    push(socket, "mcp:message", request)
    {:noreply, socket}
  end

  @impl true
  def terminate(reason, socket) do
    task_id = socket.assigns[:task_id]
    Logger.info("Client disconnected from task #{task_id}: #{inspect(reason)}")
    :ok
  end
end
