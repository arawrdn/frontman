type config = unit

module Bindings = AskTheLlmBindings
type t = {
  messageHandlers: array<string => unit>,
  errorHandlers: array<JsError.t => unit>,
  buffer: ref<string>,
}

let make = () => {
  let transport = {
    messageHandlers: [],
    errorHandlers: [],
    buffer: ref(""),
  }

  Bindings.NodeStreams.stdin->Bindings.NodeStreams.setEncoding("utf8")
  Bindings.NodeStreams.stdin->Bindings.NodeStreams.on(
    #data(
      chunk => {
        transport.buffer := transport.buffer.contents ++ chunk
        let lines = transport.buffer.contents->Stdlib.String.split("\n")

        // Keep the last incomplete line in buffer
        transport.buffer :=
          switch lines->Array.pop {
          | Some(last) => last
          | None => ""
          }

        // Process complete lines
        lines->Array.forEach(line => {
          let trimmed = line->String.trim
          if trimmed->String.length > 0 {
            transport.messageHandlers->Array.forEach(handler => handler(trimmed))
          }
        })
      },
    ),
  )

  // Handle stdin errors
  Bindings.NodeStreams.stdin->Bindings.NodeStreams.on(
    #error(
      error => {
        transport.errorHandlers->Array.forEach(handler => handler(error))
      },
    ),
  )

  transport
}

let send = async (_transport, message) => {
  let line = message ++ "\n"
  let _ = Bindings.NodeStreams.stdout->Bindings.NodeStreams.write(line)
}

let onMessage = (transport, handler) => {
  let _ = transport.messageHandlers->Array.push(handler)
}

let onError = (transport, handler) => {
  let _ = transport.errorHandlers->Array.push(handler)
}

let connect = async transport => {
  // Send transport ready event to parent
  let readyEnvelope = EventBus__Envelope.make(
    ~id=Math.random()->Float.toString,
    ~eventName=EventBus__Envelope.TransportEvents.ready,
    ~data=Js.Json.null,
  )

  let message = EventBus__Envelope.serialize(readyEnvelope)
  await send(transport, message->Js.Json.stringify)
}

let disconnect = async _transport => {
  // Cannot really disconnect STDIO
  ()
}

let isConnected = _transport => true
