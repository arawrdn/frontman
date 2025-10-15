// Main Agent module - entry point

// Load environment variables from .env file
let _ = AskTheLlmBindings.Dotenv.config()

module Bindings = AskTheLlmBindings

let run = (agent: Agent__Types.Agent.t) => {
  let shutdown = agent.eventBus->Agent__EventBus.on((request: Agent__EventBus.events) => {
    switch request {
    | UserRequest(userRequest) => Agent__Loop.processRequest(agent, userRequest)->ignore
    }
  })
  Console.error("Agent is running and listening for requests...")
  shutdown
}

module Events = Agent__Events
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}
module Loop = Agent__Loop
module StreamProcessor = Agent__StreamProcessor
