// MCP Server - browser-side tool registry and executor
// Combines local client tools with relay tools from the dev server

module Protocol = AskTheLlmFrontmanProtocol
module MCPTypes = Protocol.FrontmanProtocol__MCP
module RelayTypes = Protocol.FrontmanProtocol__Relay
module Relay = AskTheLlmFrontmanClient.FrontmanClient__Relay

type t = {
  relay: Relay.t,
  serverInfo: MCPTypes.info,
}

let make = (~relay: Relay.t, ~serverName="frontman-client", ~serverVersion="1.0.0"): t => {
  relay,
  serverInfo: {name: serverName, version: serverVersion},
}

// JSONSchema.t is JSON.t at runtime
external jsonSchemaAsJson: JSONSchema.t => JSON.t = "%identity"

// Serialize a client tool module to JSON
let serializeClientTool = (m: module(Client__Tool.T)): JSON.t => {
  module T = unpack(m)
  JSON.Encode.object(
    dict{
      "name": JSON.Encode.string(T.name),
      "description": JSON.Encode.string(T.description),
      "inputSchema": T.inputSchema->S.toJSONSchema->jsonSchemaAsJson,
    },
  )
}

// Get all tools as JSON array for MCP tools/list response
let getToolsJson = (server: t): array<JSON.t> => {
  // Get client tools
  let clientTools = Client__ToolRegistry.clientTools->Array.map(serializeClientTool)
  // Get relay tools
  let relayTools = server.relay->Relay.getToolsJson
  // Combine them
  Array.concat(clientTools, relayTools)
}

// Execute a client tool
let executeClientTool = async (
  toolModule: module(Client__Tool.T),
  ~state: Client__State__Types.state,
  ~arguments: option<Dict.t<JSON.t>>,
): MCPTypes.callToolResult => {
  module T = unpack(toolModule)
  let inputJson = arguments->Option.getOr(Dict.make())->JSON.Encode.object
  
  try {
    switch T.decodeInput(inputJson) {
    | Error(e) => {
        content: [{type_: "text", text: `Invalid input: ${e.message}`}],
        isError: Some(true),
      }
    | Ok(input) =>
      switch await T.execute(state, input) {
      | Ok(output) => {
          let outputJson = T.encodeOutput(output)
          {
            content: [{type_: "text", text: JSON.stringify(outputJson)}],
            isError: None,
          }
        }
      | Error(msg) => {
          content: [{type_: "text", text: msg}],
          isError: Some(true),
        }
      }
    }
  } catch {
  | exn =>
    let msg = exn
      ->JsExn.fromException
      ->Option.flatMap(JsExn.message)
      ->Option.getOr("Unknown error")
    {
      content: [{type_: "text", text: `Error: ${msg}`}],
      isError: Some(true),
    }
  }
}

// Execute tool - tries client tools first, then relay
let executeTool = async (
  server: t,
  ~name: string,
  ~arguments: option<Dict.t<JSON.t>>=?,
  ~onProgress: option<string => unit>=?,
): MCPTypes.callToolResult => {
  // Try client tools first
  switch Client__ToolRegistry.getTool(name) {
  | Some(toolModule) =>
    // Get current state for client tool execution
    let state = AskTheLlmReactStatestore.StateStore.getState(Client__State__Store.store)
    await executeClientTool(toolModule, ~state, ~arguments)
  | None =>
    // Try relay if it has this tool
    if server.relay->Relay.hasTool(name) {
      let result = await server.relay->Relay.executeTool(~name, ~arguments?, ~onProgress?)
      switch result {
      | Ok(toolResult) => toolResult
      | Error(msg) => {
          content: [{type_: "text", text: msg}],
          isError: Some(true),
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
let buildInitializeResult = (server: t): MCPTypes.initializeResult => {
  protocolVersion: MCPTypes.protocolVersion,
  capabilities: {
    tools: Some(Dict.make()),
    resources: None,
    prompts: None,
  },
  serverInfo: server.serverInfo,
}

// Build tools/list result
let buildToolsListResult = (server: t): MCPTypes.toolsListResult => {
  tools: getToolsJson(server),
}

// Create a server interface for use with the generic MCP handler
let toInterface = (server: t): MCPTypes.serverInterface<t> => {
  server,
  buildInitializeResult,
  buildToolsListResult,
  executeTool: (server, ~name, ~arguments, ~onProgress) =>
    executeTool(server, ~name, ~arguments?, ~onProgress?),
}

