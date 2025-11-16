module Dotenv = AskTheLlmBindings.Dotenv
module Agent = AskTheLlmAgent.Agent
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module DOMElementToComponentSource = AskTheLlmBindings.DOMElementToComponentSource

module TextEncoder = {
  type t
  @send external encode: (t, string) => Js.Typed_array.Uint8Array.t = "encode"
  @new external create: string => t = "TextEncoder"

  let encode = s => {
    let encoder = create("utf-8")
    encoder->encode(s)
  }
}

module ReadableStreamController = {
  type t
  @send external enqueue: (t, Js.Typed_array.Uint8Array.t) => unit = "enqueue"
  @send external close: t => unit = "close"
}

module ReadableStream = {
  type underlyingSource<'chunk> = {
    start?: ReadableStreamController.t => unit,
    pull?: ReadableStreamController.t => promise<unit>,
    cancel?: string => promise<unit>,
  }

  @module("stream/web") @new
  external make: underlyingSource<'chunk> => WebAPI.FileAPI.readableStream<'chunk> =
    "ReadableStream"
}

@val external queueMicrotask: (unit => unit) => unit = "queueMicrotask"

type config = {
  isDev: bool,
  basePath: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  isLightTheme: bool,
  projectRoot: string,
}

let agentInstance = ref(None)

let getOrCreateAgent = async (config: config) => {
  switch agentInstance.contents {
  | Some(agent) => agent
  | None =>
    Js.log("CREATING NEW AGENT")
    let apiKey = Dotenv.getOrThrow("ANTHROPIC_API_KEY")
    let agent = await Agent.make({projectRoot: config.projectRoot, apiKey})
    agentInstance := Some(agent)
    let _shutdown = Agent.initialize(agent)
    agent
  }
}

let ui = (_req, config: config) => {
  let clientCssTag = config.clientCssUrl->Option.mapOr("", url => 
    "<link rel=\"stylesheet\" href=\"" ++ url ++ "\">"
  )
  
  let entrypointTemplate = config.entrypointUrl->Option.mapOr("", url => 
    "<script type=\"template\" id=\"ask-the-llm-entrypoint-url\">" ++ url ++ "</script>"
  )
  
  let themeClass = config.isLightTheme ? "" : "dark"
  
  let askTheLlmHtml = 
    "<!DOCTYPE html>\n" ++
    "<html lang=\"en\" class=\"" ++ themeClass ++ "\">\n" ++
    "<head>\n" ++
    "    <meta charset=\"UTF-8\">\n" ++
    "    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">\n" ++
    "    <title>Ask the LLM</title>\n" ++
    "    " ++ entrypointTemplate ++ "\n" ++
    "    " ++ clientCssTag ++ "\n" ++
    "</head>\n" ++
    "<body>\n" ++
    "    <div id=\"root\"></div>\n" ++
    "    <script type=\"module\" src=\"" ++ config.clientUrl ++ "\"></script>\n" ++
    "</body>\n" ++
    "</html>"

  let headers = WebAPI.HeadersInit.fromDict(Dict.fromArray([("Content-Type", "text/html")]))
  // Return HTML response
  WebAPI.Response.fromString(
    askTheLlmHtml,
    ~init={
      headers: headers,
    },
  )
}

let resolveSourceLocationFromBody = async (sourceLocation: Nextjs__Types.sourceLocation): option<
  DOMElementToComponentSource.sourceLocation,
> => {
  let sourceLocation: DOMElementToComponentSource.sourceLocation = {
    componentName: sourceLocation.componentName,
    file: sourceLocation.file,
    line: sourceLocation.line,
    column: sourceLocation.column,
  }

  let resolved = await DOMElementToComponentSource.resolveSourceLocationInServer(sourceLocation)
  Some(resolved)
}

let chat = async (req, config) => {
  let body = await req->WebAPI.Request.json
  let chat = body->S.parseJsonOrThrow(Nextjs__Types.chatSchema)

  let resolvedSourceLocation = switch chat.selectedElement {
  | None => None
  | Some({sourceLocation: Some(sourceLocation)}) =>
    await resolveSourceLocationFromBody(sourceLocation)
  | Some({sourceLocation: None}) => None
  }

  switch resolvedSourceLocation {
  | Some(location) => Console.log2("[API] Using resolved source location:", location)
  | None => Console.log("[API] No source location resolved")
  }

  let agent = await getOrCreateAgent(config)

  // Convert Figma node to JSON string if present
  let selectedFigmaNode = chat.selectedFigmaNode->Option.map(node => {
    node->S.reverseConvertToJsonOrThrow(Nextjs__Types.figmaNodeSchema)->JSON.stringify
  })

  agent
  ->Agent.sendMessage(
    Agent.TaskMessage.User({
      taskId: chat.taskId,
      content: String(chat.message),
      selectedElementSourceLocation: resolvedSourceLocation,
      selectedFigmaNode,
    }),
  )
  ->ignore

  // Use standard Web API Response.json instead of NextResponse.json
  let jsonData = JSON.parseOrThrow(`{"status": "accepted", "message": "Message received and processing started"}`)
  WebAPI.Response.jsonR(
    ~data=jsonData,
    ~init={status: 202},
  )
}

let eventToSSEData = (event: AgentEventBus.events): string => {
  let jsonValue = event->S.reverseConvertOrThrow(AgentEventBus.eventsSchema)
  let data = JSON.stringifyAny(jsonValue)->Option.getOr("{}")
  "data: " ++ data ++ "\n\n"
}

let events = async (_req, config) => {
  Console.log("[SSE] Client connected to events stream")

  let agent = await getOrCreateAgent(config)

  let unsubscribeRef = ref(None)

  let stream = ReadableStream.make({
    start: controller => {
      queueMicrotask(() => {
        let unsubscribe = AskTheLlmAgent.Agent.subscribe(agent, event => {
          try {
            let sseData = eventToSSEData(event)
            let encoded = TextEncoder.encode(sseData)
            controller->ReadableStreamController.enqueue(encoded)
          } catch {
          | _ => Console.error("[SSE] Error encoding/enqueuing event")
          }
        })
        unsubscribeRef := Some(unsubscribe)
      })
    },
    cancel: _reason => {
      Console.log("[SSE] Client disconnected, cleaning up subscription")
      switch unsubscribeRef.contents {
      | Some(unsubscribe) => unsubscribe()
      | None => ()
      }
      Promise.resolve()
    },
  })

  let headers = WebAPI.HeadersInit.fromDict(
    Dict.fromArray([
      ("Content-Type", "text/event-stream"),
      ("Cache-Control", "no-cache, no-transform"),
      ("Connection", "keep-alive"),
    ]),
  )

  WebAPI.Response.fromReadableStream(stream, ~init={headers: headers})
}

let toolResult = async (req, conf) => {
  let body = await req->WebAPI.Request.json
  let result =
    body->S.parseJsonOrThrow(AskTheLlmAgent.Agent__Task__Message__Part.ToolResultPart.schema)

  let agent = await getOrCreateAgent(conf)
  let resolved = Agent.submitClientToolResult(agent, result)

  if resolved {
    let jsonData = JSON.parseOrThrow(`{"success": true}`)
    WebAPI.Response.jsonR(~data=jsonData, ~init={status: 200})
  } else {
    let jsonData = JSON.parseOrThrow(`{"error": "No pending execution found"}`)
    WebAPI.Response.jsonR(~data=jsonData, ~init={status: 404})
  }
}

// Create a standard Web API middleware function
// Returns None if the request should pass through, Some(response) if handled
let createMiddleware = (conf: config) => {
  let middleware: WebAPI.FetchAPI.request => Promise.t<option<WebAPI.FetchAPI.response>> = async (req: WebAPI.FetchAPI.request) => {
    let method = req.method->String.toLowerCase
    let path =
      WebAPI.URL.parse(~url=req.url).pathname
      ->String.split("/")
      ->Array.filter(p => !String.isEmpty(p))
      ->Array.join("/")
      ->String.toLowerCase

    switch (method, path) {
    | ("get", path) when path == conf.basePath->String.toLowerCase => 
      Some(ui(req, conf))
    | ("post", path) when path == (conf.basePath ++ "/chat")->String.toLowerCase => 
      Some(await chat(req, conf))
    | ("get", path) when path == (conf.basePath ++ "/events")->String.toLowerCase => 
      Some(await events(req, conf))
    | ("post", path) when path == (conf.basePath ++ "/tool-results")->String.toLowerCase => 
      Some(await toolResult(req, conf))
    | _ => None
    }
  }
  middleware
}

