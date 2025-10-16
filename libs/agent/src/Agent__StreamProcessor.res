// Stream processor - handles Vercel AI SDK stream events
// TODO: Consider extracting stream event conversion to Agent__Adapters__Vercel
// Currently tightly coupled to Vercel's streamPart event format

type toolStatus =
  | Pending
  | Running
  | Completed
  | Error

type toolPart = {
  id: string,
  toolCallId: string,
  toolName: string,
  status: ref<toolStatus>,
  input: option<JSON.t>,
  output: ref<option<string>>,
  error: ref<option<string>>,
  startTime: ref<option<float>>,
  endTime: ref<option<float>>,
}

// Result type returned by processor
type processResult = {
  text: string,
  toolCalls: array<toolPart>,
  hasToolCalls: bool,
}

// Process an async iterable (like ReadableStream) using for-await-of pattern
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

// Legacy function for direct async iterators (kept for compatibility)
let rec processAsyncIterator = async (
  iterator: AsyncIterator.t<'a>,
  handler: 'a => promise<unit>,
) => {
  let result = await iterator->AsyncIterator.next

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
  _requestId: string,
  stream: Agent__Bindings__VercelAI.streamTextResult,
): processResult => {
  let toolParts = Dict.make()
  let textBuffer = ref("")

  let asyncIterable = stream->Agent__Bindings__VercelAI.fullStream

  await processAsyncIterable(asyncIterable, async event => {
    switch event {
    | TextDelta({textDelta}) => textBuffer := textBuffer.contents ++ textDelta

    | ToolCall({toolCallId, toolName, args}) => {
        Console.error2("Tool call:", toolName)

        let toolPart = {
          id: toolCallId,
          toolCallId,
          toolName,
          status: ref(Running),
          input: Some(args),
          output: ref(None),
          error: ref(None),
          startTime: ref(Some(Date.now())),
          endTime: ref(None),
        }

        toolParts->Dict.set(toolCallId, toolPart)
      }

    | ToolResult({toolCallId, toolName, result}) => {
        Console.error2("Tool result:", toolName)

        switch toolParts->Dict.get(toolCallId) {
        | Some(part) => {
            part.status := Completed
            part.output := Some(result->JSON.stringify)
            part.endTime := Some(Date.now())
          }
        | None => Console.error("Tool result without matching call")
        }
      }

    | FinishStep({finishReason, usage}) => Console.error3("Step finished:", finishReason, usage)

    | Finish => Console.error("Stream finished")
    }
  })

  let toolCallsArray = toolParts->Dict.valuesToArray

  {
    text: textBuffer.contents,
    toolCalls: toolCallsArray,
    hasToolCalls: toolCallsArray->Array.length > 0,
  }
}
