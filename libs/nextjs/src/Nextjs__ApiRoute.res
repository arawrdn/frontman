// Next.js API Routes Module
// This module provides API route handlers for Next.js applications

module Agent = AskTheLlmAgent.Agent

// Next.js API Route Request type (Pages Router)
module ApiRequest = {
  type t

  @get external method: t => string = "method"
  @get external body: t => Js.Json.t = "body"
  @get external query: t => Js.Dict.t<string> = "query"
  @get external headers: t => Js.Dict.t<string> = "headers"
}

// Next.js API Route Response type (Pages Router)
module ApiResponse = {
  type t

  @send external status: (t, int) => t = "status"
  @send external json: (t, 'a) => unit = "json"
  @send external send: (t, string) => unit = "send"
  @send external setHeader: (t, string, string) => t = "setHeader"
  @send external end: (t, string) => unit = "end"
}

// API handler type for Next.js Pages Router
type apiHandler = (ApiRequest.t, ApiResponse.t) => promise<unit>

// Singleton agent instance
let agentInstance: ref<option<AskTheLlmAgent.Agent.t>> = ref(None)

let getOrCreateAgent = () => {
  switch agentInstance.contents {
  | Some(agent) => agent
  | None =>
    let projectRoot =
      AskTheLlmBindings.Process.env->Js.Dict.get("PWD")->Belt.Option.getWithDefault(".")
    let agent = Agent.make(projectRoot)
    let _shutdown = Agent.run(agent)
    agentInstance := Some(agent)
    agent
  }
}

// Handler for /api/ask-the-llm (serves the UI)
let createUIHandler = (isDev: bool): apiHandler => {
  async (_req, res) => {
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

    let _ = res->ApiResponse.setHeader("Content-Type", "text/html")
    res->ApiResponse.status(200)->ApiResponse.end(askTheLlmHtml)
  }
}

// Handler for /api/ask-the-llm/chat (handles chat messages)
let createChatHandler = (): apiHandler => {
  async (req, res) => {
    let method = ApiRequest.method(req)

    if method !== "POST" {
      res->ApiResponse.status(405)->ApiResponse.json({"error": "Method not allowed"})
    } else {
      let body = ApiRequest.body(req)
      switch Js.Json.decodeObject(body) {
      | Some(obj) =>
        switch Js.Dict.get(obj, "message") {
        | Some(messageJson) =>
          switch Js.Json.decodeString(messageJson) {
          | Some(str) =>
            if str === "" {
              res->ApiResponse.status(400)->ApiResponse.json({"error": "Message cannot be empty"})
            } else {
              let agent = getOrCreateAgent()
              let message = Agent.sendMessage(
                agent,
                Agent.TaskMessage.make(~role=User, ~parts=[Agent.Part.text(~text=str)]),
              )
              switch message {
              | Ok(task) => res->ApiResponse.status(200)->ApiResponse.json({"task": task})
              | Error(error) => res->ApiResponse.status(500)->ApiResponse.json({"error": error})
              }
            }
          | None =>
            res
            ->ApiResponse.status(400)
            ->ApiResponse.json({"error": "Message field must be a string"})
          }
        | None =>
          res
          ->ApiResponse.status(400)
          ->ApiResponse.json({"error": "Missing required field: message"})
        }
      | None => res->ApiResponse.status(400)->ApiResponse.json({"error": "Invalid JSON body"})
      }
    }
  }
}
