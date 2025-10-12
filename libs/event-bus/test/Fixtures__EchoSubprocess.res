// Simple echo subprocess that demonstrates public API usage
// This uses the exact same API that application code would use

module MyRemoteBus = EventBus.RemoteBus.Make(Fixtures__Events, EventBus.StdioTransport)
let bus = MyRemoteBus.make(())

// Step 3: Subscribe to events (PUBLIC API)
let _unsubscribe = bus->MyRemoteBus.on(event => {
  switch event {
  | Fixtures__Events.Ping({message}) => {
      // Received ping, send pong back
      // Note: Using Console.error to log to stderr (not stdout)
      Console.error("Fixture received ping: " ++ message)

      let pongEvent = Fixtures__Events.Pong({
        message: "Echo: " ++ message,
        originalMessage: message,
      })

      let _ = bus->MyRemoteBus.emit(pongEvent)
    }
  | Fixtures__Events.Pong(_) => ()
  }
})

// Step 4: Connect transport (PUBLIC API)
let _ = MyRemoteBus.connect(bus)
