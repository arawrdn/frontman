// Subprocess that crashes before sending ready signal
module MyRemoteBus = EventBus.RemoteBus.Make(Fixtures__Events, EventBus.StdioTransport)
let bus = MyRemoteBus.make()

// Register handler but don't connect - crash immediately
Console.error("Crashing before ready...")
JsError.throwWithMessage("Intentional crash for testing")
