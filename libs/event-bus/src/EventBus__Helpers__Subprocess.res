// Subprocess helper functions for EventBus

// Spawn a subprocess with stdio configured for EventBus communication
// - stdin: pipe (for sending messages)
// - stdout: pipe (for receiving messages)
// - stderr: inherit (for logging)
let spawn = (scriptPath: string): Bindings__ChildProcess.childProcess => {
  Bindings__ChildProcess.spawn(
    "node",
    [scriptPath],
    {
      stdio: ["pipe", "pipe", "inherit"],
    },
  )
}

// Kill a subprocess
let kill = (proc: Bindings__ChildProcess.childProcess): bool => {
  Bindings__ChildProcess.kill(proc)
}
