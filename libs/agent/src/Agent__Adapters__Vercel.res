// Vercel AI SDK adapter - converts domain types to Vercel format
// This is the ONLY module that should import Agent__Bindings__VercelAI

// ============ LLM Type ============

// Opaque type - hides VercelAI implementation details
module Part = Agent__Task__Message__Part
type t = {
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
}

// ============ Type Re-exports ============
// Re-export types so AgenticLoop doesn't need to import bindings directly
type vercelMessage = Agent__Bindings__VercelAI.message
type streamResult = Agent__Bindings__VercelAI.streamTextResult
type toolCallInfo = Agent__Bindings__VercelAI.toolCall
type streamEvent = Agent__Bindings__VercelAI.streamPart

// ============ Tool Conversion ============

let toVercelTools = (registry: Agent__Tools__Registry.t): Dict.t<
  Agent__Bindings__VercelAI.toolDef,
> => {
  let vercelTools = Dict.make()

  registry->Array.forEach(tool => {
    switch tool {
    | Agent__Tools__Registry.Tool({name, description, inputSchema}) =>
      // Convert Sury schema to JSON Schema
      let jsonSchemaObj = inputSchema->S.toJSONSchema

      // Wrap with AI SDK's jsonSchema helper to get proper aiSchema type
      let aiSchemaWrapped = Agent__Bindings__VercelAI.jsonSchema(jsonSchemaObj)

      let toolDef: Agent__Bindings__VercelAI.toolDef = {
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
let messageToVercel = (msg: Agent__Task__Message.t): Agent__Bindings__VercelAI.message => {
  let role = switch msg->Agent__Task__Message.getRole {
  | User => Agent__Bindings__VercelAI.User
  | Agent => Agent__Bindings__VercelAI.Assistant
  | System => Agent__Bindings__VercelAI.System
  | Tool => Agent__Bindings__VercelAI.Tool
  | Assistant => Agent__Bindings__VercelAI.Assistant
  }

  let parts = msg->Agent__Task__Message.getParts

  // Check if we have any non-text parts
  let hasStructuredParts = parts->Array.some(part => {
    switch part {
    | Part.ToolUse(_) => true
    | _ => false
    }
  })

  let content = if hasStructuredParts {
    // Build array of contentParts and serialize them to JSON
    let contentParts: array<Agent__Bindings__VercelAI.ContentPart.t> = parts->Array.map(part => {
      switch part {
      | Part.Text(textPart) => {
          let text = textPart->Part.TextPart.getText
          Agent__Bindings__VercelAI.ContentPart.Text({text: text})
        }
      | Part.ToolUse(toolUsePart) =>
        Agent__Bindings__VercelAI.ContentPart.ToolCall({
          toolCallId: toolUsePart->Part.ToolUsePart.getToolCallId,
          toolName: toolUsePart->Part.ToolUsePart.getToolName,
          args: toolUsePart->Part.ToolUsePart.getArgs,
        })
      | Part.File(filePart) => {
          let file = filePart->Part.FilePart.getFile
          let name = file->Part.File.getName->Option.getOr("unnamed")
          let mimeType = file->Part.File.getMimeType
          Agent__Bindings__VercelAI.ContentPart.Text({text: `File: ${name}, MimeType: ${mimeType}`})
        }
      | Part.Data(dataPart) => {
          let data = dataPart->Part.DataPart.getData
          Agent__Bindings__VercelAI.ContentPart.Text({text: `Data: ${data->JSON.stringify}`})
        }
      }
    })

    // Serialize the variants to JSON using Sury
    let contentPartsSchema = S.array(Agent__Bindings__VercelAI.ContentPart.schema)
    let serialized = contentParts->S.reverseConvertOrThrow(contentPartsSchema)
    // Safe cast: reverseConvertOrThrow returns JSON
    let jsonArray: array<JSON.t> = serialized->Obj.magic
    Agent__Bindings__VercelAI.Parts(jsonArray)
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
    Agent__Bindings__VercelAI.String(text)
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
  msg: Agent__Bindings__VercelAI.message,
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
      let contentPartsSchema = S.array(Agent__Bindings__VercelAI.ContentPart.schema)
      let parsedParts = contentPartsJson->S.parseOrThrow(contentPartsSchema)

      // Convert to domain Part.t
      parsedParts->Array.map(contentPart => {
        switch contentPart {
        | Agent__Bindings__VercelAI.ContentPart.Text({text}) => Part.text(~text)
        | Agent__Bindings__VercelAI.ContentPart.ToolCall({toolCallId, toolName, args}) =>
          Part.toolUse(~toolCallId, ~toolName, ~args)
        }
      })
    }
  }

  Agent__Task__Message.make(~role, ~parts, ~taskId)
}

// ============ LLM Creation ============

let makeLLM = (
  ~model: Agent__Bindings__VercelAI.languageModel,
  ~toolRegistry: Agent__Tools__Registry.t,
): t => {
  let tools = toVercelTools(toolRegistry)
  {model, tools}
}

// ============ Stream Result Accessors ============

// Accessor functions for streamResult - shields AgenticLoop from Vercel bindings
let getFullStream = (result: streamResult) => result->Agent__Bindings__VercelAI.fullStream
let getResponse = (result: streamResult) => result->Agent__Bindings__VercelAI.response
let getFinishReason = (result: streamResult) => result->Agent__Bindings__VercelAI.finishReason
let getToolCalls = (result: streamResult) => result->Agent__Bindings__VercelAI.toolCalls
let getText = (result: streamResult) => result->Agent__Bindings__VercelAI.text

// ============ Stream Processing ============

// Process an async iterable (like ReadableStream) using for-await-of pattern
// This is more efficient than recursive iteration
let processAsyncIterable = (iterable, handler) => {
  let impl: (
    Agent__Bindings__VercelAI.AsyncIterableStream.t<'a>,
    'a => promise<unit>,
  ) => promise<unit> = %raw(`
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
  await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages,
    tools: llm.tools,
  })
}
