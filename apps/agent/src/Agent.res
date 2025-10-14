// Main Agent module - entry point

// Use bindings from shared library
let parseArgs = () => {
  let projectRoot =
    Bindings__Process.argv
    ->Array.find(arg => arg->String.startsWith("--project-root="))
    ->Option.map(arg => arg->String.replace("--project-root=", ""))

  switch projectRoot {
  | Some(root) => Ok(root)
  | None => Error("Missing --project-root argument")
  }
}

let main = async () => {
  switch parseArgs() {
  | Ok(projectRoot) => {
      let agent = await Agent__Core.initialize(projectRoot)
      await Agent__Core.run(agent)
    }
  | Error(msg) => {
      Console.error(msg)
      Console.error("Usage: node Agent.res.mjs --project-root=/path/to/project")
      Bindings__Process.exit(1)
    }
  }
}

// Start agent
let _ = main()

// Export modules for testing
module Events = Agent__Events
module PluginBus = Agent__Bus__Plugin
module InternalBus = Agent__Bus__Internal
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}
module Core = Agent__Core
module Loop = Agent__Loop
module StreamProcessor = Agent__StreamProcessor
