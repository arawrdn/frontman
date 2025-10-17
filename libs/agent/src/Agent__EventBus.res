// Event bus - publishes domain events
type artifactChunkGenerated = {
  taskId: Agent__Id.t,
  artifact: Agent__Artifact.t,
  isComplete: bool,
}

type taskMessageAdded = {
  task: Agent__Task.t,
  message: Agent__Task__Message.t,
}

type events =
  | TaskCreated(Agent__Task.t)
  | TaskStateChanged(Agent__Task.t)
  | ArtifactChunkGenerated(artifactChunkGenerated)
  | TaskMessageAdded(taskMessageAdded)

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
