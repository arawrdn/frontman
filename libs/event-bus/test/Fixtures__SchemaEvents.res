// Schema-based events for testing
// Demonstrates the new low-boilerplate pattern

// Define individual events using MakeEvent functor
module PingConfig = {
  type t = {message: string}
  let name = "schema.ping"
  let schema = S.object(s => {
    message: s.field("message", S.string),
  })
}
module Ping = EventBus__Event.Make(PingConfig)

module PongConfig = {
  type t = {
    message: string,
    originalMessage: string,
  }
  let name = "schema.pong"
  let schema = S.object(s => {
    message: s.field("message", S.string),
    originalMessage: s.field("originalMessage", S.string),
  })
}
module Pong = EventBus__Event.Make(PongConfig)

// Combine into EventType module satisfying RemoteBus requirements
type t =
  | Ping(Ping.t)
  | Pong(Pong.t)

let eventName = event =>
  switch event {
  | Ping(_) => Ping.name
  | Pong(_) => Pong.name
  }

let toJson = event =>
  switch event {
  | Ping(p) => Ping.toJson(p)
  | Pong(p) => Pong.toJson(p)
  }

let fromJson = (name, json) => {
  if name == Ping.name {
    Ping.fromJson(json)->Option.map(p => Ping(p))
  } else if name == Pong.name {
    Pong.fromJson(json)->Option.map(p => Pong(p))
  } else {
    None
  }
}
