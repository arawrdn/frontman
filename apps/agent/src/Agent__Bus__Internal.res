// Internal Bus - handles internal agent communications (in-process events)

// For now, we'll use a simple LocalBus for internal events
// This can be extended later with internal event types as needed

module EventBus = AskTheLlmEventBus.EventBus
type t = EventBus.LocalBus.t<unit>

let make = () => {
  EventBus.LocalBus.make()
}

// Add internal event types and handlers here as needed
