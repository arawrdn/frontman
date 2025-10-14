// Helper functions for creating and checking agent events

open Agent.Events

// Create a user request envelope for testing
let makeTestUserRequest = (
  ~requestId: string,
  ~userMessage: string,
  ~fixtureDir: string,
  ~selectedElement: option<UserRequestConfig.selectedElement>=?,
  ()
): UserRequestConfig.t => {
  {
    requestId,
    userMessage,
    selectedElement,
    context: {
      projectRoot: fixtureDir,
      componentSource: None,
      componentTree: None,
      types: None,
      fileStructure: None,
      buildErrors: None,
    }
  }
}

// Event type predicates for PluginBus events
let isStatusUpdate = (event: Agent.PluginBus.event): bool => {
  switch event {
  | Agent.PluginBus.StatusUpdate(_) => true
  | _ => false
  }
}

let isAgentResponse = (event: Agent.PluginBus.event): bool => {
  switch event {
  | Agent.PluginBus.AgentResponse(_) => true
  | _ => false
  }
}

let isAgentError = (event: Agent.PluginBus.event): bool => {
  switch event {
  | Agent.PluginBus.AgentError(_) => true
  | _ => false
  }
}

// Extract response message
let getResponseMessage = (event: Agent.PluginBus.event): option<string> => {
  switch event {
  | Agent.PluginBus.AgentResponse(response) => Some(response.message)
  | _ => None
  }
}

// Extract error message
let getErrorMessage = (event: Agent.PluginBus.event): option<string> => {
  switch event {
  | Agent.PluginBus.AgentError(error) => Some(error.error)
  | _ => None
  }
}

// Wait for response or error event
let waitForCompletion = async (
  ~events: ref<array<Agent.PluginBus.event>>,
  ~timeout: int,
  ()
): unit => {
  await TestHelpers.waitFor(
    ~condition=() => {
      events.contents->Array.some(e =>
        isAgentResponse(e) || isAgentError(e)
      )
    },
    ~timeout,
    ()
  )
}

// Extract status update message
let getStatusMessage = (event: Agent.PluginBus.event): option<string> => {
  switch event {
  | Agent.PluginBus.StatusUpdate(status) => Some(status.message)
  | _ => None
  }
}

// Proper test failure with message
let failTest = (message: string): unit => {
  JsError.throwWithMessage(message)
}
