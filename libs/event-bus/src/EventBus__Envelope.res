// Message envelope that wraps all events
type t = {
  id: string,
  timestamp: float,
  eventName: string,
  data: JSON.t,
}

// Enable JSON support for S.json schema
S.enableJson()

let schema = S.object(s => {
  id: s.field("id", S.string),
  timestamp: s.field("timestamp", S.float),
  eventName: s.field("eventName", S.string),
  data: s.field("data", S.json),
})

let validate = (data: Js.Json.t) => {
  data->S.parseOrThrow(schema)
}

let serialize = (envelope: t) => {
  //Note(Danni) - might wanna wrap this in a result to not crash our bus
  envelope->S.reverseConvertToJsonOrThrow(schema)
}

let make = (~id: string, ~eventName: string, ~data: JSON.t) => {
  id,
  timestamp: Date.now(),
  eventName,
  data,
}

// Transport event prefix constant
let transportEventPrefix = "__transport:"

// Check if an event name is a transport-level event
let isTransportEvent = (eventName: string): bool => {
  eventName->String.startsWith(transportEventPrefix)
}

// Transport event constants
module TransportEvents = {
  let ready = transportEventPrefix ++ "ready"
}
