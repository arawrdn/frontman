// Process globals
@val external argv: array<string> = "process.argv"

@module("process")
external exit: int => unit = "exit"

// Process environment variables
@val @scope("process") external env: Dict.t<string> = "env"

// Node.js __dirname global
@val external __dirname: string = "__dirname"

// Timeout function
@val
external setTimeout: (unit => unit, int) => float = "setTimeout"
