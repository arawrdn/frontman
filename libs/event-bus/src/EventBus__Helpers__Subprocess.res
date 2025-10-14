// Subprocess helper functions for EventBus

// Spawn a subprocess with stdio configured for EventBus communication
// - stdin: pipe (for sending messages)
// - stdout: pipe (for receiving messages)
// - stderr: inherit (for logging)
module Bindings = AskTheLlmBindings
let spawn = (scriptPath: string): Bindings.ChildProcess.childProcess => {
  Bindings.ChildProcess.spawn(
    "node",
    [scriptPath],
    {
      stdio: ["pipe", "pipe", "inherit"],
    },
  )
}

// Kill a subprocess
let kill = (proc: Bindings.ChildProcess.childProcess): bool => {
  Bindings.ChildProcess.kill(proc)
}
