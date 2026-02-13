// Astro middleware for Frontman

module Config = FrontmanAstro__Config
module Server = FrontmanAstro__Server
module ToolRegistry = FrontmanAstro__ToolRegistry

// Annotation capture script - injected before </body>
// Stores paths exactly as Astro provides them (should be absolute paths)
let annotationCaptureScript = `
<script>
(function() {
  var annotations = new Map();
  document.querySelectorAll('[data-astro-source-file]').forEach(function(el) {
    annotations.set(el, {
      file: el.getAttribute('data-astro-source-file'),
      loc: el.getAttribute('data-astro-source-loc')
    });
  });
  window.__frontman_annotations__ = {
    _map: annotations,
    get: function(el) { return annotations.get(el); },
    has: function(el) { return annotations.has(el); },
    size: function() { return annotations.size; }
  };
  console.log('[Frontman] Captured ' + annotations.size + ' elements');
})();
</script>
`

// Helper to inject script into HTML response
let injectAnnotationScript = async (response: WebAPI.FetchAPI.response): WebAPI.FetchAPI.response => {
  let contentType = response.headers->WebAPI.Headers.get("content-type")->Null.toOption

  switch contentType {
  | Some(ct) if ct->String.includes("text/html") =>
    let html = await response->WebAPI.Response.text
    let injectedHtml = html->String.replace("</body>", `${annotationCaptureScript}</body>`)

    WebAPI.Response.fromString(
      injectedHtml,
      ~init={
        status: response.status,
        headers: WebAPI.HeadersInit.fromHeaders(response.headers),
      },
    )
  | _ => response
  }
}

// HTML template for the Frontman UI
let uiHtml = (~clientUrl: string) => {
  // Get the raw env var and filter out empty strings
  let openrouterKey =
    FrontmanBindings.Process.env
    ->Dict.get("OPENROUTER_API_KEY")
    ->Option.flatMap(key => key != "" ? Some(key) : None)
  // Build JSON payload using proper JSON encoding to handle special characters
  let configObj = Dict.fromArray([("framework", JSON.Encode.string("Astro"))])
  openrouterKey->Option.forEach(key => {
    configObj->Dict.set("openrouterKeyValue", JSON.Encode.string(key))
  })
  let runtimeConfig = JSON.stringify(JSON.Encode.object(configObj))
  `<!DOCTYPE html>
<html>
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Frontman</title>
  <link rel="icon" type="image/svg+xml" href="data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iNjMiIGhlaWdodD0iNjMiIHZpZXdCb3g9IjAgMCA3MDAgNzAwIiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgo8ZyBjbGlwLXBhdGg9InVybCgjY2xpcDBfMl8xMTApIj4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAxXzJfMTEwKSI+CjxwYXRoIGQ9Ik04MS40ODE1IDE5MS4yNjJMMzI3LjY5OCA0OS4xMDg4QzM2OS42MjYgMjQuOTAyMSA0MDMuNjE1IDQ0LjUyNTcgNDAzLjYxNSA5Mi45MzkzTDQwMy42MTUgMzc3LjI0NkM0MDMuNjE1IDQyNS42NiAzNjkuNjI2IDQ4NC41MzEgMzI3LjY5OCA1MDguNzM4TDgxLjQ4MTUgNjUwLjg5MUMzOS41NTQgNjc1LjA5OCA1LjU2NDg5IDY1NS40NzQgNS41NjQ3NiA2MDcuMDZMNS41NjQ3NiAzMjIuNzU0QzUuNTY0ODIgMjc0LjM0IDM5LjU1NCAyMTUuNDY5IDgxLjQ4MTUgMTkxLjI2MloiIGZpbGw9ImJsYWNrIiBzdHJva2U9IndoaXRlIiBzdHJva2Utd2lkdGg9IjE0LjIxNTMiLz4KPHJlY3Qgd2lkdGg9IjczLjQ0NTgiIGhlaWdodD0iNDkuNzUzNiIgcng9IjI0Ljg3NjgiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAxMzMuOTggMjc3LjA0NCkiIGZpbGw9IiM5NEQwQ0QiLz4KPHJlY3Qgd2lkdGg9IjEwMy4wNjEiIGhlaWdodD0iNDkuNzUzNiIgcng9IjI0Ljg3NjgiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAxMzMuODAzIDI3Ny4xNDYpIiBmaWxsPSIjRjI0RTFFIi8+CjxyZWN0IHdpZHRoPSI2Ni4zMzgxIiBoZWlnaHQ9IjQ5Ljc1MzYiIHJ4PSIyNC44NzY4IiB0cmFuc2Zvcm09Im1hdHJpeCgwLjg2NjAyNSAtMC41IDIuMjAzMDVlLTA4IDEgMTMzLjgwMyA0NDUuMzYxKSIgZmlsbD0iIzFBQkNGRSIvPgo8cmVjdCB3aWR0aD0iMTU4LjczOCIgaGVpZ2h0PSI0OS43NTM2IiByeD0iMjQuODc2OCIgdHJhbnNmb3JtPSJtYXRyaXgoMC44NjYwMjUgLTAuNSAyLjIwMzA1ZS0wOCAxIDEzMy44MDMgMzYxLjI1NCkiIGZpbGw9IiNBMjU5RkYiLz4KPHJlY3Qgd2lkdGg9IjUyLjEyMjgiIGhlaWdodD0iNDkuNzUzNiIgcng9IjI0Ljg3NjgiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAyMzUuMzY3IDIxOC41MDgpIiBmaWxsPSIjRUZDRjgxIi8+CjwvZz4KPGcgY2xpcC1wYXRoPSJ1cmwoI2NsaXAyXzJfMTEwKSI+CjxyZWN0IHg9IjYuMTU1NDEiIHk9IjMuNTUzODMiIHdpZHRoPSI0NTkuNjI4IiBoZWlnaHQ9IjQ1OS42MjgiIHJ4PSI4Ny42NjExIiB0cmFuc2Zvcm09Im1hdHJpeCgwLjg2NjAyNSAtMC41IDIuMjAzMDVlLTA4IDEgMjkwLjQ2MyAyMzQuNjE3KSIgZmlsbD0id2hpdGUiIHN0cm9rZT0iYmxhY2siIHN0cm9rZS13aWR0aD0iMTQuMjE1MyIvPgo8cGF0aCBkPSJNNDM5LjM0MyA1MjEuMjAzQzQyOS4zNDEgNTI2Ljk3OCA0MjIuMjI4IDUyOS40MTYgNDE4LjAwNSA1MjguNTE4QzQxMy43ODEgNTI3LjM2MyA0MTEuMjI1IDUyNC4zNDcgNDEwLjMzNiA1MTkuNDdDNDA5LjQ0NyA1MTQuMzM3IDQwOS4wMDIgNTA4Ljk0NyA0MDkuMDAyIDUwMy4zTDQwOS4wMDIgMzA0LjI1NkM0MDkuMDAyIDI5MC45MSA0MTEuMjI1IDI4MC41MTUgNDE1LjY3MSAyNzMuMDcxQzQyMC4zMzkgMjY1LjI0MyA0MjguNTYzIDI1Ny45MjggNDQwLjM0NCAyNTEuMTI3TDU2Mi4zNzUgMTgwLjY3MkM1NjcuNDg3IDE3Ny43MiA1NzIuMjY2IDE3NS40NzQgNTc2LjcxMiAxNzMuOTM1QzU4MS4zOCAxNzIuMjY2IDU4NS4xNTggMTczLjAzNiA1ODguMDQ4IDE3Ni4yNDRDNTkwLjkzOCAxNzkuNDUzIDU5Mi4zODIgMTg2Ljk2IDU5Mi4zODIgMTk4Ljc2N0M1OTIuMzgyIDIxMC4zMTcgNTkwLjgyNiAyMTkuNDI4IDU4Ny43MTQgMjI2LjEwMkM1ODQuODI1IDIzMi42NDcgNTgxLjA0NiAyMzcuNzggNTc2LjM3OCAyNDEuNTAyQzU3MS43MSAyNDUuMjIzIDU2Ni44MiAyNDguNTYgNTYxLjcwOCAyNTEuNTEyTDQ3MC4wMTggMzA0LjQ0OUw0NzAuMDE4IDMzOC43MTRMNTMxLjM2NyAzMDMuMjk0QzUzNi40NzkgMzAwLjM0MiA1NDEuMDM2IDI5OC4yMjUgNTQ1LjAzNyAyOTYuOTQxQzU0OS4yNiAyOTUuMjczIDU1Mi40ODMgMjk1Ljk3OSA1NTQuNzA2IDI5OS4wNTlDNTU3LjE1MSAzMDEuNzU0IDU1OC4zNzQgMzA4LjIzNSA1NTguMzc0IDMxOC41MDFDNTU4LjM3NCAzMjguMjU1IDU1Ny4xNTEgMzM1Ljg5IDU1NC43MDYgMzQxLjQwOUM1NTIuMjYxIDM0Ni45MjcgNTQ4LjkyNyAzNTEuMjkgNTQ0LjcwNCAzNTQuNDk5QzU0MC43MDMgMzU3LjU3OSA1MzYuMTQ2IDM2MC41OTQgNTMxLjAzMyAzNjMuNTQ2TDQ3MC4wMTggMzk4Ljc3M0w0NzAuMDE4IDQ2OC40NThDNDcwLjAxOCA0NzQuMTA1IDQ2OS41NzMgNDc5Ljg4IDQ2OC42ODQgNDg1Ljc4M0M0NjcuNzk1IDQ5MS42ODYgNDY1LjIzOSA0OTcuNjU0IDQ2MS4wMTYgNTAzLjY4NUM0NTYuNzkyIDUwOS40NiA0NDkuNTY4IDUxNS4yOTkgNDM5LjM0MyA1MjEuMjAzWiIgZmlsbD0iYmxhY2siLz4KPC9nPgo8L2c+CjxkZWZzPgo8Y2xpcFBhdGggaWQ9ImNsaXAwXzJfMTEwIj4KPHJlY3Qgd2lkdGg9IjcwMCIgaGVpZ2h0PSI3MDAiIGZpbGw9IndoaXRlIi8+CjwvY2xpcFBhdGg+CjxjbGlwUGF0aCBpZD0iY2xpcDFfMl8xMTAiPgo8cmVjdCB3aWR0aD0iNDczLjg0NCIgaGVpZ2h0PSI0NzMuODQ0IiBmaWxsPSJ3aGl0ZSIgdHJhbnNmb3JtPSJtYXRyaXgoMC44NjYwMjUgLTAuNSAyLjIwMzA1ZS0wOCAxIC0wLjU5MDQ1NCAyMzEuNTM5KSIvPgo8L2NsaXBQYXRoPgo8Y2xpcFBhdGggaWQ9ImNsaXAyXzJfMTEwIj4KPHJlY3Qgd2lkdGg9IjQ3My44NDQiIGhlaWdodD0iNDczLjg0NCIgZmlsbD0id2hpdGUiIHRyYW5zZm9ybT0ibWF0cml4KDAuODY2MDI1IC0wLjUgMi4yMDMwNWUtMDggMSAyODkuNjM5IDIzMS41MzkpIi8+CjwvY2xpcFBhdGg+CjwvZGVmcz4KPC9zdmc+Cg==">
  <style>
    html, body, #root {
      margin: 0;
      padding: 0;
      height: 100%;
      width: 100%;
    }
  </style>
</head>
<body>
  <div id="root"></div>
  <script>window.__frontmanRuntime=${runtimeConfig}</script>
  <script type="module" src="${clientUrl}"></script>
</body>
</html>`
}

// Serve UI HTML
let serveUI = (config: Config.t): WebAPI.FetchAPI.response => {
  let html = uiHtml(~clientUrl=config.clientUrl)
  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  WebAPI.Response.fromString(html, ~init={headers: headers})
}

// Type for Astro URL object (subset we need)
type astroUrl = {pathname: string}

// Type for Astro middleware context (subset of APIContext we actually use)
type astroContext = {
  request: WebAPI.FetchAPI.request,
  url: astroUrl,
}

// Type for Astro next function
type astroNext = unit => promise<WebAPI.FetchAPI.response>

// Create middleware handler
// Returns a function that can be used directly as Astro middleware
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()

  async (context: astroContext, next: astroNext): WebAPI.FetchAPI.response => {
    let pathname = context.url.pathname
    let method = context.request.method

    let basePath = `/${config.basePath}`

    // Check if this is a frontman route (exact match or subpath)
    if !(pathname == basePath || pathname->String.startsWith(`${basePath}/`)) {
      // Not a frontman route - pass through but inject script into HTML
      let response = await next()
      await injectAnnotationScript(response)
    } else if method == "OPTIONS" {
      // Handle CORS preflight
      Server.handleCORS()
    } else {
      // Route handling
      switch pathname {
      | p if p == basePath || p == `${basePath}/` =>
        serveUI(config)

      | p if p == `${basePath}/tools` && method == "GET" =>
        Server.handleGetTools(~registry, ~config)

      | p if p == `${basePath}/tools/call` && method == "POST" =>
        await Server.handleToolCall(~registry, ~config, context.request)

      | p if p == `${basePath}/resolve-source-location` && method == "POST" =>
        await Server.handleResolveSourceLocation(~config, context.request)

      | _ =>
        // Unknown frontman route
        WebAPI.Response.jsonR(
          ~data=JSON.Encode.object(Dict.fromArray([("error", JSON.Encode.string("Not found"))])),
          ~init={status: 404},
        )
      }
    }
  }
}
