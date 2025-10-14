// Test helper functions for agent integration tests
// Adapted from libs/event-bus/test/Integration__Helpers.res

// Timeout constants - based on actual operation characteristics
let connectionTimeout = 10000 // 10s - agent process startup and IPC handshake
let llmTimeout = 30000 // 30s - typical LLM API response time
let fullTestTimeout = 60000 // 60s - full test including retries and cleanup

// Default fixture for most tests
let defaultFixture = "sample-react-component"

module Bindings = AskTheLlmBindings
module EventBus = AskTheLlmEventBus.EventBus
// Helper to wait for a given number of milliseconds
let wait = async (ms: int): unit => {
  await Promise.make((resolve, _reject) => {
    let _ = Bindings.Process.setTimeout(() => resolve(), ms)
  })
}

// Helper to spawn the agent with a fixture project root
let spawnAgent = (fixtureDir: string): Bindings.ChildProcess.childProcess => {
  // Agent builds in-source, so use src/Agent.res.mjs
  let agentPath = Bindings.Path.join([Bindings.Process.__dirname, "../src/Agent.res.mjs"])

  Console.debug2("Spawning agent:", agentPath)
  Console.debug2("Project root:", fixtureDir)

  Bindings.ChildProcess.spawn(
    "node",
    [agentPath, `--project-root=${fixtureDir}`],
    {
      stdio: ["pipe", "pipe", "inherit"],
    },
  )
}

// Helper to get absolute path to a fixture directory
let getFixturePath = (fixtureName: string): string => {
  Bindings.Path.join([Bindings.Process.__dirname, "fixtures", fixtureName])
}

// Helper to wait for a condition with timeout
let waitFor = async (~condition: unit => bool, ~timeout: int, ~interval: int=100, ()): unit => {
  let startTime = Date.now()

  while !condition() {
    if Date.now() -. startTime > Int.toFloat(timeout) {
      JsError.throwWithMessage("Timeout waiting for condition")
    }
    await wait(interval)
  }
}

// Helper to wait for specific number of messages
let waitForMessages = async (~messages: ref<array<'a>>, ~count: int, ~timeout: int, ()): unit => {
  await waitFor(~condition=() => messages.contents->Array.length >= count, ~timeout, ())
}

// Create AgentBus module - eliminates duplication across tests
module AgentBus = EventBus.RemoteBus.Make(
  {
    type t = Agent.PluginBus.event
    let eventName = Agent.PluginBus.eventName
    let toJson = Agent.PluginBus.toJson
    let fromJson = Agent.PluginBus.fromJson
  },
  EventBus.SubprocessTransport,
)

// Type for test context cleanup
type testContext = {
  bus: AgentBus.t,
  responses: ref<array<Agent.PluginBus.event>>,
  process: Bindings.ChildProcess.childProcess,
  unsubscribe: unit => unit,
}

// Complete test setup - spawn agent, create bus, connect, setup listeners
let setupAgentTest = async (~fixtureDir: option<string>=?, ()): testContext => {
  let fixture = fixtureDir->Option.getOr(getFixturePath(defaultFixture))
  let proc = spawnAgent(fixture)
  let bus = AgentBus.make(proc)
  let responses: ref<array<Agent.PluginBus.event>> = ref([])

  let unsub = bus->AgentBus.on(event => {
    let _ = responses.contents->Array.push(event)
  })

  await AgentBus.connect(bus)

  {
    bus,
    responses,
    process: proc,
    unsubscribe: unsub,
  }
}

// Cleanup test context
let cleanupAgentTest = (ctx: testContext): unit => {
  ctx.unsubscribe()
  let _ = Bindings.ChildProcess.kill(ctx.process)
}
