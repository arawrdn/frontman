// Vercel AI SDK adapter - converts domain types to Vercel format

// ============ Tool Conversion ============

let toVercelTools = (registry: Agent__Tools__Registry.t): Dict.t<
  Agent__Bindings__VercelAI.toolDef,
> => {
  let vercelTools = Dict.make()

  registry->Array.forEach(tool => {
    switch tool {
    | Agent__Tools__Registry.Tool({name, description, inputSchema, execute}) =>
      // Convert Sury schema to JSON Schema
      let jsonSchemaObj = inputSchema->S.toJSONSchema
      
      // Wrap with AI SDK's jsonSchema helper to get proper aiSchema type
      let aiSchemaWrapped = Agent__Bindings__VercelAI.jsonSchema(jsonSchemaObj)
      
      let toolDef: Agent__Bindings__VercelAI.toolDef = {
        description: description,
        parameters: aiSchemaWrapped,
        inputSchema: aiSchemaWrapped,
        execute: async argsJson => {
          let input = argsJson->S.parseJsonOrThrow(inputSchema)
          let result = await execute(input)
          switch result {
          | Ok(output) => JSON.Encode.string(output)
          | Error(err) => {
              Console.error2(`Tool ${name} error:`, err)
              JSON.Encode.string(`Error: ${err}`)
            }
          }
        },
      }
      
      vercelTools->Dict.set(name, toolDef)
    }
  })

  vercelTools
}

// ============ Message Conversion ============

let messageToVercel = (msg: Agent__Message.t): Agent__Bindings__VercelAI.message => {
  let role = switch msg->Agent__Message.getRole {
  | User => "user"
  | Agent => "assistant"
  }

  let content =
    msg
    ->Agent__Message.getParts
    ->Array.map(part => {
      switch part {
      | Text(textPart) => textPart->Agent__Part.TextPart.getText
      | File(filePart) => {
          let file = filePart->Agent__Part.FilePart.getFile
          let name = file->Agent__Part.File.getName->Option.getOr("unnamed")
          let mimeType = file->Agent__Part.File.getMimeType
          `File: ${name}, MimeType: ${mimeType}`
        }
      | Data(dataPart) => {
          let data = dataPart->Agent__Part.DataPart.getData
          `Data: ${data->JSON.stringify}`
        }
      }
    })
    ->Array.join("\n")

  {
    Agent__Bindings__VercelAI.role,
    content: JSON.Encode.string(content),
  }
}

// Create a tool result message in Vercel format
// According to AI SDK manual agent loop docs, tool results should be in an array
// with specific structure matching the ToolResultPart type
let makeToolResultMessage = (
  toolCallId: string,
  toolName: string,
  result: string,
): Agent__Bindings__VercelAI.message => {
  // Create the tool result part
  let toolResultPart = Dict.make()
  toolResultPart->Dict.set("type", JSON.Encode.string("tool-result"))
  toolResultPart->Dict.set("toolCallId", JSON.Encode.string(toolCallId))
  toolResultPart->Dict.set("toolName", JSON.Encode.string(toolName))
  
  // AI SDK expects "output" field as LanguageModelV2ToolResultOutput
  // This is a discriminated union with type: 'text' | 'json' | 'error-text' | 'error-json'
  // For errors, use 'error-text', for success use 'text'
  let outputObj = Dict.make()
  let isError = result->String.startsWith("Error:")
  outputObj->Dict.set("type", JSON.Encode.string(isError ? "error-text" : "text"))
  outputObj->Dict.set("value", JSON.Encode.string(result))
  toolResultPart->Dict.set("output", JSON.Encode.object(outputObj))
  
  // Tool messages need content as an array of tool-result parts
  let content = JSON.Encode.array([JSON.Encode.object(toolResultPart)])
  
  {
    role: "tool",
    content,
  }
}

let messagesToVercel = (messages: array<Agent__Message.t>): array<
  Agent__Bindings__VercelAI.message,
> => {
  messages->Array.map(messageToVercel)
}
