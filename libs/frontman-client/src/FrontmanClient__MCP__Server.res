// MCP Server - browser-side tool registry and executor
// The browser acts as an MCP server, responding to tool calls from the agent

module Types = FrontmanClient__MCP__Types
module Tool = FrontmanClient__MCP__Tool
module Relay = FrontmanClient__Relay
module Log = FrontmanLogs.Logs.Make({
  let component = #MCPServer
})

// Resolved image data for write_file image_ref interception
type resolvedImage = {
  base64: string,
  mediaType: string,
}

type t = {
  tools: array<module(Tool.Tool)>,
  relay: Relay.t,
  serverInfo: Types.info,
  // Optional callback to resolve an image_ref URI to base64 data.
  // Set by the client layer which has access to the state store.
  mutable resolveImageRef: option<string => option<resolvedImage>>,
}

let make = (~relay: Relay.t, ~serverName="frontman-browser", ~serverVersion="1.0.0"): t => {
  {
    tools: [],
    relay,
    serverInfo: {name: serverName, version: serverVersion},
    resolveImageRef: None,
  }
}

// Set the image ref resolver (called from client layer after store is available)
let setImageRefResolver = (server: t, resolver: string => option<resolvedImage>): unit => {
  server.resolveImageRef = Some(resolver)
}

let registerToolModule = (server: t, toolModule: module(Tool.Tool)): t => {
  {
    ...server,
    tools: Array.concat(server.tools, [toolModule]),
  }
}

// JSONSchema.t is JSON.t at runtime
external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

// Tool wire format schema - serialized directly to JSON
let toolWireSchema = S.object(s => {
  {
    "name": s.field("name", S.string),
    "description": s.field("description", S.string),
    "inputSchema": s.field("inputSchema", S.json),
    "visibleToAgent": s.field("visibleToAgent", S.bool),
  }
})

// Serialize a tool module to JSON
let serializeTool = (m: module(Tool.Tool)): JSON.t => {
  module T = unpack(m)
  {
    "name": T.name,
    "description": T.description,
    "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    "visibleToAgent": T.visibleToAgent,
  }->S.reverseConvertToJsonOrThrow(toolWireSchema)
}

// Get tools as JSON array for MCP tools/list response
let getToolsJson = (server: t): array<JSON.t> => {
  let localTools = server.tools->Array.map(serializeTool)
  let relayTools = server.relay->Relay.getToolsJson
  Array.concat(localTools, relayTools)
}

let getToolByName = (server: t, name: string): option<module(Tool.Tool)> => {
  server.tools->Array.find(m => {
    module T = unpack(m)
    T.name == name
  })
}

// Execute a local tool module
let executeLocalTool = async (
  toolModule: module(Tool.Tool),
  ~arguments: option<Dict.t<JSON.t>>,
): Types.callToolResult => {
  module T = unpack(toolModule)
  Log.debug(~ctx={"tool": T.name}, "Executing local tool")
  let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
  try {
    let input = inputJson->S.parseOrThrow(T.inputSchema)
    Log.debug(~ctx={"tool": T.name}, "Calling execute")
    let result = await T.execute(input)
    Log.debug(~ctx={"tool": T.name}, "Execute returned")
    switch result {
    | Ok(output) =>
      let outputJson = output->S.reverseConvertToJsonOrThrow(T.outputSchema)
      {
        content: [{type_: "text", text: JSON.stringify(outputJson)}],
        isError: None,
      }
    | Error(msg) => {
        content: [{type_: "text", text: msg}],
        isError: Some(true),
      }
    }
  } catch {
  | S.Error(e) =>
    Log.error(~ctx={"tool": T.name}, "Schema error")
    {
      content: [{type_: "text", text: `Invalid input: ${e.message}`}],
      isError: Some(true),
    }
  }
}

// Resolve image_ref in write_file arguments before forwarding to relay.
// Replaces image_ref with content (base64) and encoding ("base64").
let resolveWriteFileImageRef = (
  server: t,
  arguments: option<Dict.t<JSON.t>>,
): result<option<Dict.t<JSON.t>>, string> => {
  switch arguments {
  | None => Ok(None)
  | Some(args) =>
    switch args->Dict.get("image_ref") {
    | None => Ok(Some(args)) // No image_ref, pass through
    | Some(imageRefJson) =>
      let imageRef = switch imageRefJson {
      | String(s) => s
      | _ => ""
      }
      if imageRef == "" {
        Error("image_ref must be a non-empty string")
      } else {
        switch server.resolveImageRef {
        | None =>
          Error("Cannot resolve image_ref: no resolver configured")
        | Some(resolve) =>
          switch resolve(imageRef) {
          | None =>
            Error(`Image not found for URI: ${imageRef}. Available images may have expired or the URI is incorrect.`)
          | Some({base64}) =>
            // Build new arguments: remove image_ref, add content + encoding
            let newArgs = Dict.make()
            args->Dict.forEachWithKey((value, key) => {
              if key != "image_ref" {
                newArgs->Dict.set(key, value)
              }
            })
            newArgs->Dict.set("content", JSON.Encode.string(base64))
            newArgs->Dict.set("encoding", JSON.Encode.string("base64"))
            Ok(Some(newArgs))
          }
        }
      }
    }
  }
}

// Execute tool - tries local first, then relay
let executeTool = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~onProgress: option<string => unit>=?,
): Types.callToolResult => {
  // Try local tools first
  switch getToolByName(server, name) {
  | Some(toolModule) => await executeLocalTool(toolModule, ~arguments)
  | None =>
    // Try relay if it has this tool
    if server.relay->Relay.hasTool(name) {
      // Intercept write_file with image_ref to resolve from state
      let resolvedArgs = if name == "write_file" {
        switch resolveWriteFileImageRef(server, arguments) {
        | Ok(args) => Ok(args)
        | Error(msg) => Error(msg)
        }
      } else {
        Ok(arguments)
      }

      switch resolvedArgs {
      | Error(msg) => {
          content: [{type_: "text", text: msg}],
          isError: Some(true),
        }
      | Ok(finalArgs) =>
        let result = await server.relay->Relay.executeTool(~name, ~arguments=?finalArgs, ~onProgress?)
        switch result {
        | Ok(toolResult) => toolResult
        | Error(msg) => {
            content: [{type_: "text", text: msg}],
            isError: Some(true),
          }
        }
      }
    } else {
      {
        content: [{type_: "text", text: `Tool not found: ${name}`}],
        isError: Some(true),
      }
    }
  }
}

// Build initialize result response
let buildInitializeResult = (server: t): Types.initializeResult => {
  {
    protocolVersion: Types.protocolVersion,
    capabilities: {
      tools: Some(Dict.make()),
      resources: None,
      prompts: None,
    },
    serverInfo: server.serverInfo,
  }
}

// Build tools/list result
let buildToolsListResult = (server: t): Types.toolsListResult => {
  {tools: getToolsJson(server)}
}

// Create a server interface for use with the generic MCP handler
let toInterface = (server: t): Types.serverInterface<t> => {
  server,
  buildInitializeResult,
  buildToolsListResult,
  executeTool: (server, ~name, ~arguments, ~onProgress) =>
    executeTool(server, ~name, ~arguments?, ~onProgress?),
}
