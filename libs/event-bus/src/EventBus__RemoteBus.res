// Remote event bus for cross-process communication
// Serializes events at transport boundaries

module type EventType = {
  type t
  let eventName: t => string
  let toJson: t => Js.Json.t
  let fromJson: (string, Js.Json.t) => option<t>
}

module Make = (E: EventType, T: EventBus__Transport.Interface) => {
  type t = {
    transport: T.t,
    handlers: ref<array<E.t => unit>>,
  }

  let make = (config: T.config) => {
    let transport = T.make(config)
    let bus = {
      transport,
      handlers: ref([]),
    }

    // Setup transport message handling
    T.onMessage(bus.transport, rawMessage => {
      let json = rawMessage->JSON.parseOrThrow
      let envelope = EventBus__Envelope.validate(json)

      let eventName = envelope.eventName
      let eventData = envelope.data

      switch E.fromJson(eventName, eventData) {
      | Some(event) => bus.handlers.contents->Array.forEach(handler => handler(event))
      | None => Console.error("Unknown event type: " ++ eventName)
      }
    })

    bus
  }

  // Emit typed event - bus handles serialization internally
  let emit = async (bus, event: E.t) => {
    let envelope = EventBus__Envelope.make(
      ~id=Math.random()->Float.toString,
      ~eventName=E.eventName(event),
      ~data=E.toJson(event),
    )

    let message = EventBus__Envelope.serialize(envelope)
    await T.send(bus.transport, message->Js.Json.stringify)
  }

  let on = (bus, handler: E.t => unit) => {
    let _ = bus.handlers.contents->Array.push(handler)

    () => {
      bus.handlers := bus.handlers.contents->Array.filter(h => h !== handler)
    }
  }

  let connect = async bus => {
    await T.connect(bus.transport)
  }

  let disconnect = async bus => {
    await T.disconnect(bus.transport)
  }
}
