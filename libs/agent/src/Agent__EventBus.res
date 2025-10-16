// Emit event
let emit = (bus: Agent__Types.EventBus.t, event: Agent__Types.EventBus.events) => {
  bus.handlers.contents->Array.forEach(handler => handler(event))
}

// Subscribe to events
let on = (bus: Agent__Types.EventBus.t, handler: Agent__Types.EventBus.events => unit) => {
  let _ = bus.handlers.contents->Array.push(handler)

  // Return unsubscribe function
  () => {
    bus.handlers := bus.handlers.contents->Array.filter(h => h !== handler)
  }
}
