// Node.js path module bindings

@module("path") @variadic
external join: array<string> => string = "join"

@module("path")
external dirname: string => string = "dirname"

@module("path")
external basename: string => string = "basename"

@module("path")
external extname: string => string = "extname"

@module("path")
external resolve: string => string = "resolve"
