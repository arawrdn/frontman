// Additional Node.js bindings for path and globals

// __dirname global (available in CommonJS and when using --experimental-detect-module)
@val external __dirname: string = "__dirname"

// Path module
module Path = {
  @module("node:path") @variadic
  external join: array<string> => string = "join"

  @module("node:path")
  external dirname: string => string = "dirname"

  @module("node:path")
  external basename: string => string = "basename"
}

// setTimeout for promises
@val
external setTimeout: (unit => unit, int) => float = "setTimeout"
