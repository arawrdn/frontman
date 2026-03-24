defmodule SwarmAi.RuntimeTest do
  use SwarmAi.Testing, async: true

  describe "child_spec/1" do
    test "requires :name option" do
      assert_raise KeyError, fn ->
        SwarmAi.Runtime.child_spec([])
      end
    end

    test "returns a supervisor child spec" do
      spec = SwarmAi.Runtime.child_spec(name: TestRuntime)
      assert spec.type == :supervisor
      assert spec.id == {SwarmAi.Runtime, TestRuntime}
    end
  end

  describe "run/5" do
    test "dispatches completed event on success" do
      runtime = start_runtime!()
      agent = test_agent(mock_llm("Echo: Hello"))

      {:ok, pid} =
        SwarmAi.Runtime.run(
          runtime,
          "task-complete",
          agent,
          "Hello",
          default_opts(metadata: %{my_key: "my_val"})
        )

      await_exit(pid)
      assert_receive {:test_event, "task-complete", {:completed, {:ok, "Echo: Hello", _loop_id}}}

      refute SwarmAi.Runtime.running?(runtime, "task-complete")
    end

    test "dispatches completed event with metadata passed to dispatcher" do
      runtime = start_runtime_with_metadata_dispatch!()
      agent = test_agent(mock_llm("Echo: Hello"))

      {:ok, pid} =
        SwarmAi.Runtime.run(
          runtime,
          "task-meta",
          agent,
          "Hello",
          default_opts(metadata: %{my_key: "my_val"})
        )

      await_exit(pid)

      assert_receive {:test_event_with_meta, "task-meta",
                      {:completed, {:ok, "Echo: Hello", _loop_id}}, metadata}

      assert metadata.my_key == "my_val"
    end

    test "dispatches failed event on LLM error" do
      runtime = start_runtime!()
      agent = test_agent(%ErrorLLM{error: :llm_api_failure})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-error", agent, "Hello", default_opts())

      await_exit(pid)

      assert_receive {:test_event, "task-error", {:failed, {:error, _reason, _loop_id}}}
    end

    test "prevents duplicate execution for same key" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 500})

      {:ok, _} = SwarmAi.Runtime.run(runtime, "task-dup", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.run(runtime, "task-dup", agent, "World", default_opts()) ==
               {:error, :already_running}
    end
  end

  describe "running?/2" do
    test "returns true while running, false when not" do
      runtime = start_runtime!()
      assert SwarmAi.Runtime.running?(runtime, "no-such") == false

      agent = test_agent(%MockLLM{response: "slow", delay_ms: 500})
      {:ok, _} = SwarmAi.Runtime.run(runtime, "task-r", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.running?(runtime, "task-r") == true
    end
  end

  describe "cancel/2" do
    test "dispatches cancelled (not crashed) and unregisters" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: "slow", delay_ms: 5000})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-c", agent, "Hello", default_opts())

      assert SwarmAi.Runtime.cancel(runtime, "task-c") == :ok
      await_exit(pid)

      assert_receive {:test_event, "task-c", {:cancelled, _}}
      refute_receive {:test_event, "task-c", {:crashed, _}}, 100
      refute SwarmAi.Runtime.running?(runtime, "task-c")
    end

    test "returns error when not running" do
      runtime = start_runtime!()
      assert SwarmAi.Runtime.cancel(runtime, "nope") == {:error, :not_running}
    end
  end

  describe "crash handling" do
    test "dispatches crashed with exception and stacktrace for raises" do
      runtime = start_runtime!()
      agent = test_agent(%StreamErrorLLM{error_message: "boom"})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-crash", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-crash", {:crashed, %{reason: reason, stacktrace: st}}}

      assert is_exception(reason)
      assert is_list(st) and length(st) > 0
      refute SwarmAi.Runtime.running?(runtime, "task-crash")
    end

    test "dispatches crashed with {reason, []} for non-exception exits" do
      runtime = start_runtime!()
      agent = test_agent(%MockLLM{response: fn -> exit(:kaboom) end})

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-exit", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-exit", {:crashed, %{reason: :kaboom, stacktrace: []}}}
    end
  end

  describe "streaming events" do
    test "dispatches chunk and response events" do
      runtime = start_runtime!()
      agent = test_agent(mock_llm("Hi"))

      {:ok, pid} = SwarmAi.Runtime.run(runtime, "task-s", agent, "Hello", default_opts())
      await_exit(pid)

      assert_receive {:test_event, "task-s", {:chunk, _}}
      assert_receive {:test_event, "task-s", {:response, _}}
    end
  end

  describe "sys.get_state barrier prevents dispatch race" do
    test "slow dispatcher completes before :sys.get_state returns" do
      runtime = start_runtime_with_slow_dispatch!()
      agent = test_agent(%StreamErrorLLM{error_message: "barrier boom"})

      {:ok, pid} =
        SwarmAi.Runtime.run(runtime, "task-barrier", agent, "Hello", default_opts())

      # Step 1: execution process is dead, :DOWN is queued in the monitor
      await_exit(pid)

      # Step 2: slow dispatch (200ms) hasn't finished yet — race window is open
      refute_received {:slow_event, "task-barrier", {:crashed, _}}

      # Step 3: sync barrier — blocks until the monitor processes the :DOWN message
      monitor = SwarmAi.Runtime.monitor_name(runtime)
      :sys.get_state(monitor)

      # Step 4: dispatch has completed after the barrier
      assert_received {:slow_event, "task-barrier", {:crashed, _}}
    end
  end

  # --- Test Dispatchers ---

  defmodule TestDispatcher do
    def dispatch(test_pid, key, event, _metadata) do
      send(test_pid, {:test_event, key, event})
    end
  end

  defmodule MetadataTestDispatcher do
    def dispatch(test_pid, key, event, metadata) do
      send(test_pid, {:test_event_with_meta, key, event, metadata})
    end
  end

  defmodule SlowDispatcher do
    def dispatch(test_pid, key, event, _metadata) do
      Process.sleep(200)
      send(test_pid, {:slow_event, key, event})
    end
  end

  # --- Helpers ---

  defp start_runtime! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi.Runtime,
       name: name, event_dispatcher: {__MODULE__.TestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp start_runtime_with_metadata_dispatch! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi.Runtime,
       name: name, event_dispatcher: {__MODULE__.MetadataTestDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp start_runtime_with_slow_dispatch! do
    name = :"TestRuntime_#{:erlang.unique_integer([:positive])}"
    test_pid = self()

    start_supervised!(
      {SwarmAi.Runtime,
       name: name, event_dispatcher: {__MODULE__.SlowDispatcher, :dispatch, [test_pid]}}
    )

    name
  end

  defp default_opts(extra \\ []) do
    Keyword.merge([tool_executor: fn _ -> {:ok, "done"} end], extra)
  end

  defp await_exit(pid) do
    ref = Process.monitor(pid)
    assert_receive {:DOWN, ^ref, :process, ^pid, _}, 2000
  end
end
