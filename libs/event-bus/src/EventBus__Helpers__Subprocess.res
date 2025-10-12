// Subprocess helper functions for EventBus

module ChildProcess = EventBus__Bindings__ChildProcess

// Spawn a subprocess with stdio configured for EventBus communication
// - stdin: pipe (for sending messages)
// - stdout: pipe (for receiving messages)
// - stderr: inherit (for logging)
let spawn = (scriptPath: string): ChildProcess.childProcess => {
  ChildProcess.spawn(
    "node",
    [scriptPath],
    {
      stdio: ["pipe", "pipe", "inherit"],
    },
  )
}

// Kill a subprocess
let kill = (proc: ChildProcess.childProcess): bool => {
  ChildProcess.kill(proc)
}
