// Middleware factory for NextJS

module Server = FrontmanNextjs__Server
module Config = FrontmanNextjs__Config
module LogCapture = FrontmanNextjs__LogCapture

type config = Config.t

// CORS headers for cross-origin requests (e.g., browser test page on different port)
let corsHeaders = Dict.fromArray([
  ("Access-Control-Allow-Origin", "*"),
  ("Access-Control-Allow-Methods", "GET, POST, OPTIONS"),
  ("Access-Control-Allow-Headers", "Content-Type"),
])

// Add CORS headers to a response
let withCors = (response: WebAPI.FetchAPI.response): WebAPI.FetchAPI.response => {
  let headers = response.headers
  corsHeaders->Dict.forEachWithKey((value, key) => {
    headers->WebAPI.Headers.set(~name=key, ~value)
  })
  response
}

// Handle OPTIONS preflight request
let handlePreflight = (): WebAPI.FetchAPI.response => {
  let headers = WebAPI.HeadersInit.fromDict(corsHeaders)
  WebAPI.Response.fromNull(~init={status: 204, headers})
}

// Handle UI endpoint - serves the frontman client HTML
let handleUI = (config: config): WebAPI.FetchAPI.response => {
  let clientCssTag =
    config.clientCssUrl->Option.mapOr("", url => `<link rel="stylesheet" href="${url}">`)

  let entrypointTemplate =
    config.entrypointUrl->Option.mapOr("", url =>
      `<script type="template" id="frontman-entrypoint-url">${url}</script>`
    )

  let themeClass = config.isLightTheme ? "" : "dark"

  let runtimeConfigScript = {
    // Get the raw env var and filter out empty strings
    let openrouterKey =
      FrontmanBindings.Process.env
      ->Dict.get("OPENROUTER_API_KEY")
      ->Option.flatMap(key => key != "" ? Some(key) : None)
    let frameworkLabel = "Next.js"
    // Build JSON payload using proper JSON encoding to handle special characters
    let configObj = Dict.fromArray([("framework", JSON.Encode.string(frameworkLabel))])
    // Add key value if present and non-empty
    openrouterKey->Option.forEach(key => {
      configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
    })
    let payload = JSON.stringify(JSON.Encode.object(configObj))
    `<script>window.__frontmanRuntime=${payload}</script>`
  }

  let html = `<!DOCTYPE html>
<html lang="en" class="${themeClass}">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Frontman</title>
    <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjMiIGhlaWdodD0iNjMiIHZpZXdCb3g9IjAgMCA3MDAgNzAwIiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgo8ZyBjbGlwLXBhdGg9InVybCgjY2xpcDBfMl8xMTApIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAxXzJfMTEwKSI+CjxwYXRoIGQ9Ik04MS40ODE1IDE5MS4yNjJMMzI3LjY5OCA0OS4xMDg4QzM2OS42MjYgMjQuOTAyMSA0MDMuNjE1IDQ0LjUyNTcgNDAzLjYxNSA5Mi45MzkzTDQwMy42MTUgMzc3LjI0NkM0MDMuNjE1IDQyNS42NiAzNjkuNjI2IDQ4NC41MzEgMzI3LjY5OCA1MDguNzM4TDgxLjQ4MTUgNjUwLjg5MUMzOS41NTQgNjc1LjA5OCA1LjU2NDg5IDY1NS40NzQgNS41NjQ3NiA2MDcuMDZMNS41NjQ3NiAzMjIuNzU0QzUuNTY0ODIgMjc0LjM0IDM5LjU1NCAyMTUuNDY5IDgxLjQ4MTUgMTkxLjI2MloiIGZpbGw9ImJsYWNrIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjE0LjIxNTMiLz4KPHJlY3Qgd2lkdGg9IjczLjQ0NTgiIGhlaWdodD0iNDkuNzUzNiIgcng9IjI0Ljg3NjgiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAxMzMuOTggMjc3LjA0NCkiIGZpbGw9IiM5NEQwQ0QiLz4KPHJlY3Qgd2lkdGg9IjEwMy4wNjEiIGhlaWdodD0iNDkuNzUzNiIgcng9IjI0Ljg3NjgiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAxMzMuODAzIDI3Ny4xNDYpIiBmaWxsPSIjRjI0RTFFIi8+CjxyZWN0IHdpZHRoPSI2Ni4zMzgxIiBoZWlnaHQ9IjQ5Ljc1MzYiIHJ4PSIyNC44NzY4IiB0cmFuc2Zvcm09Im1hdHJpeCgwLjg2NjAyNSAtMC41IDIuMjAzMDVlLTA4IDEgMTMzLjgwMyA0NDUuMzYxKSIgZmlsbD0iIzFBQkNGRSIvPgo8cmVjdCB3aWR0aD0iMTU4LjczOCIgaGVpZ2h0PSI0OS43NTM2IiByeD0iMjQuODc2OCIgdHJhbnNmb3JtPSJtYXRyaXgoMC44NjYwMjUgLTAuNSAyLjIwMzA1ZS0wOCAxIDEzMy44MDMgMzYxLjI1NCkiIGZpbGw9IiNBMjU5RkYiLz4KPHJlY3Qgd2lkdGg9IjUyLjEyMjgiIGhlaWdodD0iNDkuNzUzNiIgcng9IjI0Ljg3NjgiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAyMzUuMzY3IDIxOC41MDgpIiBmaWxsPSIjRUZDRjgxIi8+CjwvZz4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAyXzJfMTEwKSI+CjxyZWN0IHg9IjYuMTU1NDEiIHk9IjMuNTUzODMiIHdpZHRoPSI0NTkuNjI4IiBoZWlnaHQ9IjQ1OS42MjgiIHJ4PSI4Ny42NjExIiB0cmFuc2Zvcm09Im1hdHJpeCgwLjg2NjAyNSAtMC41IDIuMjAzMDVlLTA4IDEgMjkwLjQ2MyAyMzQuNjE3KSIgZmlsbD0id2hpdGUiIHN0cm9rZT0iYmxhY2siIHN0cm9rZS13aWR0aD0iMTQuMjE1MyIvPgo8cGF0aCBkPSJNNDM5LjM0MyA1MjEuMjAzQzQyOS4zNDEgNTI2Ljk3OCA0MjIuMjI4IDUyOS40MTYgNDE4LjAwNSA1MjguNTE4QzQxMy43ODEgNTI3LjM2MyA0MTEuMjI1IDUyNC4zNDcgNDEwLjMzNiA1MTkuNDdDNDA5LjQ0NyA1MTQuMzM3IDQwOS4wMDIgNTA4Ljk0NyA0MDkuMDAyIDUwMy4zTDQwOS4wMDIgMzA0LjI1NkM0MDkuMDAyIDI5MC45MSA0MTEuMjI1IDI4MC41MTUgNDE1LjY3MSAyNzMuMDcxQzQyMC4zMzkgMjY1LjI0MyA0MjguNTYzIDI1Ny45MjggNDQwLjM0NCAyNTEuMTI3TDU2Mi4zNzUgMTgwLjY3MkM1NjcuNDg3IDE3Ny43MiA1NzIuMjY2IDE3NS40NzQgNTc2LjcxMiAxNzMuOTM1QzU4MS4zOCAxNzIuMjY2IDU4NS4xNTggMTczLjAzNiA1ODguMDQ4IDE3Ni4yNDRDNTkwLjkzOCAxNzkuNDUzIDU5Mi4zODIgMTg2Ljk2IDU5Mi4zODIgMTk4Ljc2N0M1OTIuMzgyIDIxMC4zMTcgNTkwLjgyNiAyMTkuNDI4IDU4Ny43MTQgMjI2LjEwMkM1ODQuODI1IDIzMi42NDcgNTgxLjA0NiAyMzcuNzggNTc2LjM3OCAyNDEuNTAyQzU3MS43MSAyNDUuMjIzIDU2Ni44MiAyNDguNTYgNTYxLjcwOCAyNTEuNTEyTDQ3MC4wMTggMzA0LjQ0OUw0NzAuMDE4IDMzOC43MTRMNTMxLjM2NyAzMDMuMjk0QzUzNi40NzkgMzAwLjM0MiA1NDEuMDM2IDI5OC4yMjUgNTQ1LjAzNyAyOTYuOTQxQzU0OS4yNiAyOTUuMjczIDU1Mi40ODMgMjk1Ljk3OSA1NTQuNzA2IDI5OS4wNTlDNTU3LjE1MSAzMDEuNzU0IDU1OC4zNzQgMzA4LjIzNSA1NTguMzc0IDMxOC41MDFDNTU4LjM3NCAzMjguMjU1IDU1Ny4xNTEgMzM1Ljg5IDU1NC43MDYgMzQxLjQwOUM1NTIuMjYxIDM0Ni45MjcgNTQ4LjkyNyAzNTEuMjkgNTQ0LjcwNCAzNTQuNDk5QzU0MC43MDMgMzU3LjU3OSA1MzYuMTQ2IDM2MC41OTQgNTMxLjAzMyAzNjMuNTQ2TDQ3MC4wMTggMzk4Ljc3M0w0NzAuMDE4IDQ2OC40NThDNDcwLjAxOCA0NzQuMTA1IDQ2OS41NzMgNDc5Ljg4IDQ2OC42ODQgNDg1Ljc4M0M0NjcuNzk1IDQ5MS42ODYgNDY1LjIzOSA0OTcuNjU0IDQ2MS4wMTYgNTAzLjY4NUM0NTYuNzkyIDUwOS40NiA0NDkuNTY4IDUxNS4yOTkgNDM5LjM0MyA1MjEuMjAzWiIgZmlsbD0iYmxhY2siLz4KPC9nPgo8L2c+CjxkZWZzPgo8Y2xpcFBhdGggaWQ9ImNsaXAwXzJfMTEwIj4KPHJlY3Qgd2lkdGg9IjcwMCIgaGVpZ2h0PSI3MDAiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjxjbGlwUGF0aCBpZD0iY2xpcDFfMl8xMTAiPgo8cmVjdCB3aWR0aD0iNDczLjg0NCIgaGVpZ2h0PSI0NzMuODQ0IiBmaWxsPSJ3aGl0ZSIgdHJhbnNmb3JtPSJtYXRyaXgoMC44NjYwMjUgLTAuNSAyLjIwMzA1ZS0wOCAxIC0wLjU5MDQ1NCAyMzEuNTM5KSIvPgo8L2NsaXBQYXRoPgo8Y2xpcFBhdGggaWQ9ImNsaXAyXzJfMTEwIj4KPHJlY3Qgd2lkdGg9IjQ3My44NDQiIGhlaWdodD0iNDczLjg0NCIgZmlsbD0id2hpdGUiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAyODkuNjM5IDIzMS41MzkpIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==">
    ${entrypointTemplate}
    ${clientCssTag}
</head>
<body>
    <div id="root"></div>
    ${runtimeConfigScript}
    <script type="module" src="${config.clientUrl}"></script>
</body>
</html>`

  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}

// Create middleware from a config input object (applies defaults)
let createMiddleware = (configInput: Config.jsConfigInput) => {
  let config = Config.makeFromObject(configInput)
  let server = Server.make(
    ~projectRoot=config.projectRoot,
    ~sourceRoot=config.sourceRoot,
    ~serverName=config.serverName,
    ~serverVersion=config.serverVersion,
  )

  let middleware: WebAPI.FetchAPI.request => promise<
    option<WebAPI.FetchAPI.response>,
  > = async req => {
    let method = req.method->String.toLowerCase
    let pathname = WebAPI.URL.parse(~url=req.url).pathname

    // Normalize path: remove leading slash, lowercase
    let path =
      pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
      ->Array.join("/")
      ->String.toLowerCase

    let toolsPath = config.basePath->String.toLowerCase ++ "/tools"
    let toolsCallPath = config.basePath->String.toLowerCase ++ "/tools/call"
    let resolveSourceLocationPath =
      config.basePath->String.toLowerCase ++ "/resolve-source-location"

    let uiPath = config.basePath->String.toLowerCase

    // Check if this is a frontman route (for CORS preflight)
    let isFrontmanRoute =
      path == toolsPath ||
      path == toolsCallPath ||
      path == resolveSourceLocationPath ||
      path == uiPath

    switch (method, path) {
    | ("options", _) if isFrontmanRoute => Some(handlePreflight())
    | ("get", p) if p == uiPath => Some(handleUI(config)->withCors)
    | ("get", p) if p == toolsPath => Some(server->Server.handleGetTools->withCors)
    | ("post", p) if p == toolsCallPath =>
      Some((await server->Server.handleToolCall(req))->withCors)
    | ("post", p) if p == resolveSourceLocationPath =>
      Some((await server->Server.handleResolveSourceLocation(req))->withCors)
    | _ => None
    }
  }

  middleware
}
