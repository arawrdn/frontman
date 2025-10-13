// Stream processor - handles Vercel AI SDK stream events

// Tool execution state
type toolStatus =
  | Pending
  | Running
  | Completed
  | Error

type toolPart = {
  id: string,
  toolCallId: string,
  toolName: string,
  mutable status: toolStatus,
  mutable input: option<JSON.t>,
  mutable output: option<string>,
  mutable error: option<string>,
  mutable startTime: option<float>,
  mutable endTime: option<float>,
}

let rec processAsyncIterator = async (
  iterator: Agent__Bindings__VercelAI.asyncIterator<'a>,
  handler: 'a => promise<unit>,
) => {
  let result = await iterator->Agent__Bindings__VercelAI.next

  switch result.done {
  | true => ()
  | false =>
    switch result.value {
    | Some(value) => {
        await handler(value)
        await processAsyncIterator(iterator, handler)
      }
    | None => ()
    }
  }
}

// Process stream and collect events
let process = async (
  requestId: string,
  stream: Agent__Bindings__VercelAI.streamTextResult,
  onStatus: string => promise<unit>,
) => {
  let toolParts = Dict.make()
  let textBuffer = ref("")

  let iterator = stream->Agent__Bindings__VercelAI.fullStream

  await processAsyncIterator(iterator, async event => {
    switch event {
    | TextDelta({textDelta}) => {
        textBuffer := textBuffer.contents ++ textDelta
      }

    | ToolCall({toolCallId, toolName, args}) => {
        Console.log2("Tool call:", toolName)

        let toolPart = {
          id: toolCallId,
          toolCallId,
          toolName,
          status: Running,
          input: Some(args),
          output: None,
          error: None,
          startTime: Some(Date.now()),
          endTime: None,
        }

        toolParts->Dict.set(toolCallId, toolPart)
        await onStatus(`Executing ${toolName}...`)
      }

    | ToolResult({toolCallId, toolName, result}) => {
        Console.log2("Tool result:", toolName)

        switch toolParts->Dict.get(toolCallId) {
        | Some(part) => {
            part.status = Completed
            part.output = Some(result->JSON.stringify)
            part.endTime = Some(Date.now())
          }
        | None => Console.error("Tool result without matching call")
        }
      }

    | FinishStep({finishReason, usage}) => {
        Console.log3("Step finished:", finishReason, usage)
      }

    | Finish => {
        Console.log("Stream finished")
      }
    }
  })

  {
    "text": textBuffer.contents,
    "toolParts": toolParts,
  }
}
