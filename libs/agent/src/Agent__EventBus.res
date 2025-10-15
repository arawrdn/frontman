type userRequest = {message: string, selectedElement: string, requestId: string}
type events = UserRequest(userRequest)
type t = {handlers: ref<array<events => unit>>}

let make = () => {
  handlers: ref([]),
}

// Emit event - fully typed, zero overhead
let emit = (bus: t, event: 'event) => {
  bus.handlers.contents->Array.forEach(handler => handler(event))
}

// Subscribe to events
let on = (bus: t, handler: 'event => unit) => {
  let _ = bus.handlers.contents->Array.push(handler)

  // Return unsubscribe function
  () => {
    bus.handlers := bus.handlers.contents->Array.filter(h => h !== handler)
  }
}
