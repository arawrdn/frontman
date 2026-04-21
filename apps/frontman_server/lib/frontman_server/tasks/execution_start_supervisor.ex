defmodule FrontmanServer.Tasks.ExecutionStartSupervisor do
  @moduledoc false

  use Supervisor

  @registry FrontmanServer.Tasks.ExecutionStartRegistry
  @dynamic_supervisor FrontmanServer.Tasks.ExecutionStartDynamicSupervisor

  @spec start_link(keyword()) :: Supervisor.on_start()
  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    children = [
      {Registry, keys: :unique, name: @registry},
      {DynamicSupervisor, name: @dynamic_supervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
