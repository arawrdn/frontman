module Types = Client__Types
module Agent = AskTheLlmAgent.Agent
module AgentEventBus = AskTheLlmAgent.Agent__EventBus

let useSSE = (newEventCallback: AgentEventBus.events => unit) => {
  React.useEffect(() => {
    let eventSource = WebAPI.EventSource.make(~url="/api/ask-the-llm/chat-sse")
    let onOpen = _ => {
      Console.log("[SSE] Connection opened")
    }
    let onMessage = event => {
      let data = event->WebAPI.MessageEvent.data
      switch data {
      | `{"type":"connected"}` => ()
      | _ =>
        let msg = data->JSON.parseOrThrow->S.parseOrThrow(AgentEventBus.eventsSchema)
        Console.log2("[SSE] Parsed message:", msg)
        newEventCallback(msg)
      }
    }
    let onError = error => {
      Console.log2("[SSE] Error occurred:", error)
      eventSource->WebAPI.EventSource.close
    }
    eventSource->WebAPI.EventSource.addEventListener(Custom("open"), onOpen)
    eventSource->WebAPI.EventSource.addEventListener(Custom("message"), onMessage)
    eventSource->WebAPI.EventSource.addEventListener(Custom("error"), onError)

    Some(
      () => {
        eventSource->WebAPI.EventSource.removeEventListener(Custom("open"), onOpen)
        eventSource->WebAPI.EventSource.removeEventListener(Custom("message"), onMessage)
        eventSource->WebAPI.EventSource.removeEventListener(Custom("error"), onError)
        eventSource->WebAPI.EventSource.close
      },
    )
  }, [newEventCallback])
}
