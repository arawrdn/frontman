// Event bus - publishes domain events using reactor pattern
// Wraps aggregate domain events with the aggregate state for reactors

type events =
  | TaskEvent(Agent__Task.t, Agent__Task__Events.t)
  // Future: ProjectEvent, UserEvent, etc.

type t = {handlers: ref<array<events => unit>>}

let make = () => {
  handlers: ref([]),
}

let subscribe = (bus: t, handler: events => unit): unit => {
  bus.handlers := Array.concat(bus.handlers.contents, [handler])
}

// Emit event
let emit = (bus: t, event: events) => {
  bus.handlers.contents->Array.forEach(handler => handler(event))
}

// Subscribe to events (alias with unsubscribe support)
let on = (bus: t, handler: events => unit) => {
  let _ = bus.handlers.contents->Array.push(handler)

  // Return unsubscribe function
  () => {
    bus.handlers := bus.handlers.contents->Array.filter(h => h !== handler)
  }
}
