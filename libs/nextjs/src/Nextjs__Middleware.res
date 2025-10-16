// Next.js Middleware Module
// This module provides middleware functionality for Next.js applications
module Request = {
  type t

  @get external url: t => string = "url"
  @get external method: t => string = "method"
  @get external headers: t => WebAPI.FetchAPI.headers = "headers"
}

module Response = {
  type t

  type responseInit = {
    status: int,
    headers: Js.Dict.t<string>,
  }

  @module("next/server") @new
  external makeWithInit: (string, responseInit) => t = "NextResponse"

  @module("next/server") @scope("NextResponse")
  external next: unit => t = "next"

  @module("next/server") @scope("NextResponse")
  external redirect: string => t = "redirect"

  @module("next/server") @scope("NextResponse")
  external rewrite: string => t = "rewrite"

  @module("next/server") @scope("NextResponse")
  external json: 'a => t = "json"

  let html = (
    ~content: string,
    ~status: int=200,
    ~headers: Js.Dict.t<string>=Js.Dict.empty(),
    (),
  ) => {
    let responseHeaders = Js.Dict.fromArray([("Content-Type", "text/html")])
    headers
    ->Js.Dict.entries
    ->Js.Array2.forEach(((key, value)) => {
      responseHeaders->Js.Dict.set(key, value)
    })
    makeWithInit(content, {status, headers: responseHeaders})
  }
}

module Config = {
  type matcher =
    | String(string)
    | Array(array<string>)

  type t = {matcher: matcher}

  let make = (~matcher) => {
    {matcher: matcher}
  }
}

// Middleware handler type
type handler = Request.t => promise<Response.t>

let getPathname = (url: string): string => {
  let urlObj = WebAPI.URL.make(~url)
  urlObj.pathname
}

let createMiddleware = (isDev: bool) => {
  let middleware: handler = req => {
    let pathname = getPathname(Request.url(req))

    switch pathname {
    | "/ask-the-llm" =>
      let askTheLlmHtml = `!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Ask the LLM</title>
</head>
<body>
    <div id="root"></div>
    <script type="module" src="${Nextjs__Config.askTheLlmClientJsUrl(isDev)}"></script>
</body>
</html>>`

      let requestHeaders = Request.headers(req)
      // Convert headers to dictionary using Object.fromEntries
      let headersDict: Js.Dict.t<string> = %raw(`(headers) => Object.fromEntries(headers)`)(
        requestHeaders,
      )

      Response.html(~content=askTheLlmHtml, ~status=200, ~headers=headersDict, ())->Promise.resolve
    //TODO(Itay): Integrate to the agent here
    | "/ask-the-llm/chat" => Response.next()->Promise.resolve
    | _ => Response.next()->Promise.resolve
    }
  }
  middleware
}

// Main middleware that handles /ask-the-llm route

// Configuration that matches the /ask-the-llm route
let config = Config.make(~matcher=Array(["/ask-the-llm"]))
