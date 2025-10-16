type taskStateChanged = {
  taskId: Agent__Id.t,
  contextId: option<Agent__Id.t>,
}

type artifactChunkGenerated = {
  taskId: Agent__Id.t,
  contextId: option<Agent__Id.t>,
  artifact: Agent__Artifact.t,
  isComplete: bool,
}

type taskMessageAdded = {
  taskId: Agent__Id.t,
  message: Agent__Message.t,
}

type events =
  | TaskStateChanged(taskStateChanged)
  | ArtifactChunkGenerated(artifactChunkGenerated)
  | TaskMessageAdded(taskMessageAdded)

type t = {handlers: ref<array<events => unit>>}

let make = () => {
  handlers: ref([]),
}

// Emit event
let emit = (bus: t, event: events) => {
  bus.handlers.contents->Array.forEach(handler => handler(event))
}

// Subscribe to events
let on = (bus: t, handler: events => unit) => {
  let _ = bus.handlers.contents->Array.push(handler)

  // Return unsubscribe function
  () => {
    bus.handlers := bus.handlers.contents->Array.filter(h => h !== handler)
  }
}
