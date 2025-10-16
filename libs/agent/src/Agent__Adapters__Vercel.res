// Vercel AI SDK adapter - converts domain types to Vercel format
// This is the ONLY module that should import Agent__Bindings__VercelAI

// ============ LLM Type ============

// Opaque type - hides VercelAI implementation details
type t = {
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
}

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
        description,
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

let messageToVercel = (msg: Agent__Task__Message.t): Agent__Bindings__VercelAI.message => {
  let role = switch msg->Agent__Task__Message.getRole {
  | User => "user"
  | Agent => "assistant"
  }

  let content =
    msg
    ->Agent__Task__Message.getParts
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

let messagesToVercel = (messages: array<Agent__Task__Message.t>): array<
  Agent__Bindings__VercelAI.message,
> => {
  messages->Array.map(messageToVercel)
}

// ============ LLM Creation ============

let makeLLM = (
  ~model: Agent__Bindings__VercelAI.languageModel,
  ~toolRegistry: Agent__Tools__Registry.t,
): t => {
  let tools = toVercelTools(toolRegistry)
  {model, tools}
}

// ============ Tool Execution ============

let executeTool = async (llm: t, ~toolName: string, ~args: JSON.t): result<string, string> => {
  switch llm.tools->Dict.get(toolName) {
  | Some(toolDef) =>
    try {
      let result = await toolDef.execute(args)
      Ok(result->JSON.stringify)
    } catch {
    | exn => {
        let message =
          exn
          ->JsExn.fromException
          ->Option.flatMap(JsExn.message)
          ->Option.getOr("Unknown error")
        Error(`Tool execution failed: ${message}`)
      }
    }
  | None => Error(`Tool ${toolName} not found in registry`)
  }
}

// ============ Stream Processing ============

// Process an async iterable (like ReadableStream) using for-await-of pattern
// This is more efficient than recursive iteration
let processAsyncIterable: (
  Agent__Bindings__VercelAI.AsyncIterableStream.t<'a>,
  'a => promise<unit>,
) => promise<unit> = %raw(`
  async function(iterable, handler) {
    for await (const chunk of iterable) {
      await handler(chunk);
    }
  }
`)

// ============ Stream Text ============

// Stream text with Vercel messages directly (for manual loop control)
let streamTextWithVercelMessages = async (
  llm: t,
  messages: array<Agent__Bindings__VercelAI.message>,
): Agent__Bindings__VercelAI.streamTextResult => {
  await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages,
    tools: llm.tools,
  })
}

let streamText = async (
  llm: t,
  ~messages: array<Agent__Task__Message.t>,
): Agent__StreamProcessor.processResult => {
  // Convert messages to Vercel format
  let vercelMessages = messagesToVercel(messages)

  // Call Vercel AI SDK
  let stream = await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: llm.tools,
  })

  // Process the stream and convert to domain result
  let toolParts = Dict.make()
  let textBuffer = ref("")

  let asyncIterable = stream->Agent__Bindings__VercelAI.fullStream

  await processAsyncIterable(asyncIterable, async event => {
    switch event {
    | Agent__Bindings__VercelAI.TextDelta({textDelta}) =>
      textBuffer := textBuffer.contents ++ textDelta

    | ToolCall({toolCallId, toolName, args}) => {
        Console.log2("Tool call:", toolName)

        let toolPart: Agent__StreamProcessor.toolPart = {
          id: toolCallId,
          toolCallId,
          toolName,
          status: ref(Agent__StreamProcessor.Running),
          input: Some(args),
          output: ref(None),
          error: ref(None),
          startTime: ref(Some(Date.now())),
          endTime: ref(None),
        }

        toolParts->Dict.set(toolCallId, toolPart)
      }

    | ToolResult({toolCallId, toolName, result}) => {
        Console.log2("Tool result:", toolName)

        switch toolParts->Dict.get(toolCallId) {
        | Some(part) => {
            part.status := Agent__StreamProcessor.Completed
            part.output := Some(result->JSON.stringify)
            part.endTime := Some(Date.now())
          }
        | None => Console.error("Tool result without matching call")
        }
      }

    | FinishStep({finishReason, usage}) => Console.log3("Step finished:", finishReason, usage)

    | Finish => Console.log("Stream finished")
    }
  })

  let toolCallsArray = toolParts->Dict.valuesToArray

  {
    Agent__StreamProcessor.text: textBuffer.contents,
    toolCalls: toolCallsArray,
    hasToolCalls: toolCallsArray->Array.length > 0,
  }
}
