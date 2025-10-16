// Next.js Middleware Module
// This module provides middleware functionality for Next.js applications

// Helper to get the current working directory (project root)
module Agent = AskTheLlmAgent.Agent

@val @scope("process") external cwd: unit => string = "cwd"

module Request = {
  type t

  @get external url: t => string = "url"
  @get external method: t => string = "method"
  @get external headers: t => WebAPI.FetchAPI.headers = "headers"
  @send external json: t => promise<Js.Json.t> = "json"
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
  let projectRoot = cwd()
  let agent = Agent.make(projectRoot)
  let _shutdown = Agent.run(agent)

  let middleware: handler = async req => {
    let pathname = getPathname(Request.url(req))

    switch pathname {
    | "/ask-the-llm" =>
      let askTheLlmHtml = `<!DOCTYPE html>
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
</html>`

      let requestHeaders = Request.headers(req)
      // Convert headers to dictionary using Object.fromEntries
      let headersDict: Js.Dict.t<string> = %raw(`(headers) => Object.fromEntries(headers)`)(
        requestHeaders,
      )

      Response.html(~content=askTheLlmHtml, ~status=200, ~headers=headersDict, ())
    | "/ask-the-llm/chat" =>
      let method = Request.method(req)
      if method !== "POST" {
        Response.next()
      } else {
        let json = await Request.json(req)
        switch Js.Json.decodeObject(json) {
        | Some(obj) =>
          switch Js.Dict.get(obj, "message") {
          | Some(messageJson) =>
            switch Js.Json.decodeString(messageJson) {
            | Some(str) =>
              if str === "" {
                Response.json({"error": "Message cannot be empty"})
              } else {
                let message = Agent.sendMessage(
                  agent,
                  Agent.Message.make(
                    ~role=User,
                    ~parts=[Agent.Part.text(~text=str)],
                  ),
                )
                switch message {
                | Ok((messageId, _task)) => Response.json({"messageId": messageId})
                | Error(error) => Response.json({"error": error})
                }
              }
            | None => Response.json({"error": "Message field must be a string"})
            }
          | None => Response.json({"error": "Missing required field: message"})
          }
        | None => Response.json({"error": "Invalid JSON body"})
        }
      }
    | _ => Response.next()
    }
  }
  middleware
}

// Main middleware that handles /ask-the-llm route

// Configuration that matches the /ask-the-llm route
let config = Config.make(~matcher=Array(["/ask-the-llm", "/ask-the-llm/chat"]))
