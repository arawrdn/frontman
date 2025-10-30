module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

// Import required types
module AgentEventBus = AskTheLlmAgent.Agent__EventBus
module Vercel = AskTheLlmAgent.Agent__Bindings__Vercel

@react.component
let make = () => {
  // Handle SSE events and dispatch to state
  let handleSSEEvent = React.useCallback((event: AgentEventBus.events) => {
    switch event {
    | StreamEvent(_task, TextStart({id})) => Client__State.Actions.streamingStarted(~id)

    | StreamEvent(_task, TextDelta({id, text})) =>
      Client__State.Actions.textDeltaReceived(~id, ~text)

    | StreamEvent(_task, TextEnd({id})) => Client__State.Actions.messageCompleted(~id)
    | StreamEvent(_, Start(_))
    | StreamEvent(_, FinishStep(_))
    | StreamEvent(_, StartStep(_))
    | StreamEvent(_, Finish(_))
    | StreamEvent(_, ReasoningStart(_))
    | StreamEvent(_, ReasoningDelta(_))
    | StreamEvent(_, ReasoningEnd(_))
    | StreamEvent(_, ToolCall(_))
    | StreamEvent(_, ToolInputStart(_))
    | StreamEvent(_, ToolInputDelta(_))
    | StreamEvent(_, ToolInputEnd(_))
    | StreamEvent(_, ToolResult(_))
    | StreamEvent(_, ToolError(_))
    | StreamEvent(_, Source(_))
    | StreamEvent(_, File(_))
    | StreamEvent(_, Abort(_))
    | StreamEvent(_, Error(_))
    | StreamEvent(_, Raw(_))
    | // Ignore tasks for now
    TaskEvent(_, _) => ()
    }
  }, [])

  // Connect SSE
  Client__Hooks.useSSE(handleSSEEvent)

  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  let originUrl = `${currentUrl.protocol}//${currentUrl.host}`

  <div className="flex h-screen w-screen dark bg-background text-foreground">
    <div className="h-full w-96 border-r flex flex-col p-2">
      <Client__Chatbox />
    </div>
    <div className="grow h-full p-1">
      <Client__WebPreview url={originUrl} />
    </div>
  </div>
}
