// Main Agent module - entry point

@val external argv: array<string> = "process.argv"
@module("process") external exit: int => unit = "exit"

let parseArgs = () => {
  let projectRoot = argv
    ->Array.find(arg => arg->String.startsWith("--project-root="))
    ->Option.map(arg => arg->String.replace("--project-root=", ""))

  switch projectRoot {
  | Some(root) => Ok(root)
  | None => Error("Missing --project-root argument")
  }
}

let main = async () => {
  // Parse CLI args
  switch parseArgs() {
  | Ok(projectRoot) => {
      // Initialize agent
      let agent = await Agent__Core.initialize(projectRoot)

      // Run agent (blocks until killed)
      await Agent__Core.run(agent)
    }
  | Error(msg) => {
      Console.error(msg)
      Console.error("Usage: node Agent.res.mjs --project-root=/path/to/project")
      exit(1)
    }
  }
}

// Start agent
let _ = main()

// Export modules for testing
module Events = Agent__Events
module PluginBus = Agent__Bus__Plugin
module InternalBus = Agent__Bus__Internal
module Bindings = {
  module Fs = Agent__Bindings__Fs
  module Path = Agent__Bindings__Path
  module VercelAI = Agent__Bindings__VercelAI
}
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
  module Registry = Agent__Tools__Registry
}
module Core = Agent__Core
module Loop = Agent__Loop
module StreamProcessor = Agent__StreamProcessor
