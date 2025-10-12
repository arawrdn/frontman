// Local event bus for in-process communication
// Zero serialization overhead - just passing typed values

type t<'event> = {
  mutable handlers: array<'event => unit>,
}

let make = () => {
  handlers: [],
}

// Emit event - fully typed, zero overhead
let emit = (bus: t<'event>, event: 'event) => {
  bus.handlers->Array.forEach(handler => handler(event))
}

// Subscribe to events
let on = (bus: t<'event>, handler: 'event => unit) => {
  let _ = bus.handlers->Array.push(handler)

  // Return unsubscribe function
  () => {
    bus.handlers = bus.handlers->Array.filter(h => h !== handler)
  }
}
