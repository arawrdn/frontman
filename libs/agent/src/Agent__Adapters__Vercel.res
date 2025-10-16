// Vercel AI SDK adapter - converts domain types to Vercel format

// ============ Tool Conversion ============

let toVercelTools = (registry: Agent__Tools__Registry.t): Dict.t<
  Agent__Bindings__VercelAI.toolDef,
> => {
  let vercelTools = Dict.make()

  registry->Array.forEach(tool => {
    switch tool {
    | Agent__Tools__Registry.Tool({name, description, inputSchema, execute}) =>
      let toolDef: Agent__Bindings__VercelAI.toolDef = {
        description: Some(description),
        inputSchema: inputSchema->S.toJSONSchema,
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
    content: Agent__Bindings__VercelAI.StringContent(content),
  }
}

// Create a tool result message in Vercel format
let makeToolResultMessage = (
  toolCallId: string,
  toolName: string,
  result: string,
): Agent__Bindings__VercelAI.message => {
  {
    role: "tool",
    content: Agent__Bindings__VercelAI.ArrayContent([
      {
        type_: "tool-result",
        toolCallId,
        toolName,
        result: JSON.Encode.string(result),
      },
    ]),
  }
}

let messagesToVercel = (messages: array<Agent__Message.t>): array<
  Agent__Bindings__VercelAI.message,
> => {
  messages->Array.map(messageToVercel)
}
