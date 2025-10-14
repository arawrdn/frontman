// Bindings for Node.js child_process module

type childProcess

type spawnOptions = {
  stdio?: array<string>,
  cwd?: string,
  env?: Js.Dict.t<string>,
}

// Spawn a child process
@module("node:child_process")
external spawn: (string, array<string>, spawnOptions) => childProcess = "spawn"

// ChildProcess properties - now reference Bindings__NodeStreams
@get external stdin: childProcess => option<Bindings__NodeStreams.writable> = "stdin"
@get external stdout: childProcess => option<Bindings__NodeStreams.readable> = "stdout"
@get external stderr: childProcess => option<Bindings__NodeStreams.readable> = "stderr"

// ChildProcess methods
@send external kill: (childProcess, ~signal: string=?) => bool = "kill"

// Event listeners for child process
@send
external on: (
  childProcess,
  @string
  [
    | #exit((option<int>, option<string>) => unit)
    | #error(JsError.t => unit)
    | #close((option<int>, option<string>) => unit)
  ],
) => unit = "on"
