// Node.js fs module bindings

type fd
type stats

module Promises = {
  @module("fs") @scope("promises")
  external readFile: (string, @as("utf8") _) => promise<string> = "readFile"

  @module("fs") @scope("promises")
  external writeFile: (string, string, @as("utf8") _) => promise<unit> = "writeFile"

  @module("fs") @scope("promises")
  external readdir: string => promise<array<string>> = "readdir"

  @module("fs") @scope("promises")
  external stat: string => promise<stats> = "stat"

  @module("fs") @scope("promises")
  external access: (string, int) => promise<unit> = "access"
}

@get external isFile: stats => bool = "isFile"
@get external isDirectory: stats => bool = "isDirectory"

// Access mode constants
@module("fs") @scope("constants") external f_OK: int = "F_OK"
@module("fs") @scope("constants") external r_OK: int = "R_OK"
@module("fs") @scope("constants") external w_OK: int = "W_OK"
