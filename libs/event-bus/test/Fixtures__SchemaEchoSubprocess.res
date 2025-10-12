// Echo subprocess using schema events
// Mirrors Fixtures__EchoSubprocess but with SchemaEvents

module Bus = EventBus.RemoteBus.Make(
  Fixtures__SchemaEvents,
  EventBus.StdioTransport
)

let bus = Bus.make()

// Handle incoming events
let _unsubscribe = bus->Bus.on(event => {
  switch event {
  | Fixtures__SchemaEvents.Ping({message}) => {
      Console.error("Schema fixture received ping: " ++ message)

      let pongEvent = Fixtures__SchemaEvents.Pong({
        message: "Echo: " ++ message,
        originalMessage: message,
      })

      let _ = bus->Bus.emit(pongEvent)
    }
  | Fixtures__SchemaEvents.Pong(_) => ()
  }
})

// Connect and start listening
let _ = Bus.connect(bus)
