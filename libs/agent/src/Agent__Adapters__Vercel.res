// Vercel AI SDK adapter - converts domain types to Vercel format
// This is the ONLY module that should import Bindings
//

// ============ LLM Type ============

// Opaque type - hides Vercel implementation details
module Bindings = Agent__Bindings__Vercel

module Part = Agent__Task__Message__Part
type t = {
  model: Bindings.languageModel,
  tools: Dict.t<Bindings.toolDef>,
}

// ============ Type Re-exports ============
// Re-export types so AgenticLoop doesn't need to import bindings directly
type vercelMessage = Bindings.message
type streamResult = Bindings.streamTextResult
type toolCallInfo = Bindings.toolCall
type streamEvent = Bindings.streamPart

// ============ Tool Conversion ============

let toVercelTools = (registry: Agent__Tools__Registry.t): Dict.t<Bindings.toolDef> => {
  let vercelTools = Dict.make()

  registry->Array.forEach(tool => {
    switch tool {
    | Agent__Tools__Registry.Tool({name, description, inputSchema}) =>
      // Convert Sury schema to JSON Schema
      let jsonSchemaObj = inputSchema->S.toJSONSchema

      // Wrap with AI SDK's jsonSchema helper to get proper aiSchema type
      let aiSchemaWrapped = Bindings.jsonSchema(jsonSchemaObj)

      let toolDef: Bindings.toolDef = {
        description,
        parameters: aiSchemaWrapped,
        inputSchema: aiSchemaWrapped,
      }

      vercelTools->Dict.set(name, toolDef)
    }
  })

  vercelTools
}

// ============ Message Conversion ============
let messageToVercel = (msg: Agent__Task__Message.t): Bindings.message => {
  let roleToVercel = role =>
    switch msg->Agent__Task__Message.getRole {
    | User => Bindings.User
    | Agent => Bindings.Assistant
    | System => Bindings.System
    | Tool => Bindings.Tool
    | Assistant => Bindings.Assistant
    }


  let parts = msg->Agent__Task__Message.getParts

  let hasStructuredParts = parts->Array.some(part => {
    switch part {
    | Part.ToolUse(_) => true
    | _ => false
    }
  })

  let content = if hasStructuredParts {
    // Build array of contentParts and serialize them to JSON
    let contentParts: array<Bindings.ContentPart.t> = parts->Array.map(part => {
      switch part {
      | Part.Text(textPart) => {
          let text = textPart->Part.TextPart.getText
          Bindings.ContentPart.Text({text: text})
        }
      | Part.ToolUse(toolUsePart) =>
        Bindings.ContentPart.ToolCall({
          toolCallId: toolUsePart->Part.ToolUsePart.getToolCallId,
          toolName: toolUsePart->Part.ToolUsePart.getToolName,
          args: toolUsePart->Part.ToolUsePart.getArgs,
        })
      | Part.File(filePart) => {
          let file = filePart->Part.FilePart.getFile
          let name = file->Part.File.getName->Option.getOr("unnamed")
          let mimeType = file->Part.File.getMimeType
          Bindings.ContentPart.Text({text: `File: ${name}, MimeType: ${mimeType}`})
        }
      | Part.Data(dataPart) => {
          let data = dataPart->Part.DataPart.getData
          Bindings.ContentPart.Text({text: `Data: ${data->JSON.stringify}`})
        }
      }
    })

    // Serialize the variants to JSON using Sury
    let contentPartsSchema = S.array(Bindings.ContentPart.schema)
    let serialized = contentParts->S.reverseConvertOrThrow(contentPartsSchema)
    // Safe cast: reverseConvertOrThrow returns JSON
    let jsonArray: array<JSON.t> = serialized->Obj.magic
    Bindings.Parts(jsonArray)
  } else {
    // Simple text-only message
    let text =
      parts
      ->Array.map(part => {
        switch part {
        | Part.Text(textPart) => textPart->Part.TextPart.getText
        | Part.File(filePart) => {
            let file = filePart->Part.FilePart.getFile
            let name = file->Part.File.getName->Option.getOr("unnamed")
            let mimeType = file->Part.File.getMimeType
            `File: ${name}, MimeType: ${mimeType}`
          }
        | Part.Data(dataPart) => {
            let data = dataPart->Part.DataPart.getData
            `Data: ${data->JSON.stringify}`
          }
        | _ => ""
        }
      })
      ->Array.join("\n")
    Bindings.String(text)
  }

  {
    role,
    content,
  }
}

let messagesToVercel = (messages: array<Agent__Task__Message.t>): array<vercelMessage> => {
  messages->Array.map(messageToVercel)
}

// Convert Vercel message back to domain message
let messageFromVercel = (
  msg: Bindings.message,
  ~taskId: option<Agent__Task__Id.t>=None,
): Agent__Task__Message.t => {
  let role = switch msg.role {
  | User => Agent__Task__Message.User
  | Assistant => Agent__Task__Message.Agent
  | System => Agent__Task__Message.System
  | Tool => Agent__Task__Message.Tool
  }

  // Parse content using Sury
  let parts = switch msg.content {
  | String(text) => [Part.text(~text)]
  | Parts(contentPartsJson) => {
      // Parse the array of content parts using Sury
      let contentPartsSchema = S.array(Bindings.ContentPart.schema)
      let parsedParts = contentPartsJson->S.parseOrThrow(contentPartsSchema)

      // Convert to domain Part.t
      parsedParts->Array.map(contentPart => {
        switch contentPart {
        | Bindings.ContentPart.Text({text}) => Part.text(~text)
        | Bindings.ContentPart.ToolCall({toolCallId, toolName, args}) =>
          Part.toolUse(~toolCallId, ~toolName, ~args)
        }
      })
    }
  }

  Agent__Task__Message.make(~role, ~parts, ~taskId)
}

// ============ LLM Creation ============

let makeLLM = (~model: Bindings.languageModel, ~toolRegistry: Agent__Tools__Registry.t): t => {
  let tools = toVercelTools(toolRegistry)
  {model, tools}
}

// ============ Stream Result Accessors ============

// Accessor functions for streamResult - shields AgenticLoop from Vercel bindings
let getFullStream = (result: streamResult) => result->Bindings.fullStream
let getResponse = (result: streamResult) => result->Bindings.response
let getFinishReason = (result: streamResult) => result->Bindings.finishReason
let getToolCalls = (result: streamResult) => result->Bindings.toolCalls
let getText = (result: streamResult) => result->Bindings.text

// ============ Stream Processing ============

// Process an async iterable (like ReadableStream) using for-await-of pattern
// This is more efficient than recursive iteration
let processAsyncIterable = (iterable, handler) => {
  let impl: (Bindings.AsyncIterableStream.t<'a>, 'a => promise<unit>) => promise<unit> = %raw(`
    async function(iterable, handler) {
      for await (const chunk of iterable) {
        await handler(chunk);
      }
    }
  `)
  impl(iterable, handler)
}

// ============ Stream Text ============

// Stream text with Vercel messages directly (for manual loop control)
let streamText = async (llm: t, messages: array<Agent__Task__Message.t>): streamResult => {
  let messages = messagesToVercel(messages)
  await Bindings.streamText({
    model: llm.model,
    messages,
    tools: llm.tools,
  })
}
