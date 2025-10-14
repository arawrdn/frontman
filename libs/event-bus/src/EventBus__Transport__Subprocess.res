// SubprocessTransport - Transport for communicating with a subprocess via stdin/stdout
// This is the counterpart to StdioTransport:
// - StdioTransport: Use when your code runs INSIDE a subprocess
// - SubprocessTransport: Use when your code controls a subprocess

type config = Bindings__ChildProcess.childProcess

type t = {
  proc: Bindings__ChildProcess.childProcess,
  messageHandlers: array<string => unit>,
  errorHandlers: array<JsError.t => unit>,
  buffer: ref<string>,
  connected: ref<bool>,
  readyResolve: ref<option<unit => unit>>,
  readyReject: ref<option<JsError.t => unit>>,
  messageBuffer: ref<array<string>>,
}

let send = async (transport, message) => {
  if !transport.connected.contents {
    // Buffer the message until ready
    let _ = transport.messageBuffer.contents->Array.push(message)
  } else {
    // Send immediately if ready
    let stdin = Bindings__ChildProcess.stdin(transport.proc)->Option.getOrThrow
    let fullMessage = message ++ "\n"
    let _ = Bindings__NodeStreams.write(stdin, fullMessage)
  }
}
let make = proc => {
  let transport = {
    proc,
    messageHandlers: [],
    errorHandlers: [],
    buffer: ref(""),
    connected: ref(false),
    readyResolve: ref(None),
    readyReject: ref(None),
    messageBuffer: ref([]),
  }

  // Setup stdout listener for receiving messages from subprocess
  switch Bindings__ChildProcess.stdout(proc) {
  | Some(stdout) =>
    Bindings__NodeStreams.on(
      stdout,
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
              // Try to parse as envelope to check for transport events
              try {
                let json = trimmed->JSON.parseOrThrow
                let envelope = EventBus__Envelope.validate(json)

                // Check if it's the ready signal
                if envelope.eventName === EventBus__Envelope.TransportEvents.ready {
                  transport.connected := true

                  // Resolve the ready promise
                  let resolve = transport.readyResolve.contents->Option.getOrThrow
                  resolve()
                  transport.readyResolve := None

                  // Flush buffered messages by sending them
                  let _stdin =
                    Bindings__ChildProcess.stdin(transport.proc)->Option.getOrThrow
                  transport.messageBuffer.contents->Array.forEach(bufferedMsg => {
                    let _: promise<unit> = send(transport, bufferedMsg)
                  })
                  transport.messageBuffer := []
                } else {
                  // Regular user event - pass to handlers
                  transport.messageHandlers->Array.forEach(handler => handler(trimmed))
                }
              } catch {
              | _ =>
                // Not a valid envelope, pass through as-is
                transport.messageHandlers->Array.forEach(handler => handler(trimmed))
              }
            }
          })
        },
      ),
    )

    Bindings__NodeStreams.on(
      stdout,
      #error(
        error => {
          transport.errorHandlers->Array.forEach(handler => handler(error))
        },
      ),
    )
  | None => JsError.throwWithMessage("Failed to get stdout from subprocess")
  }

  // Listen for subprocess exit/error to reject ready promise if not ready yet
  Bindings__ChildProcess.on(
    proc,
    #exit(
      (code, signal) => {
        if !transport.connected.contents {
          switch transport.readyReject.contents {
          | Some(reject) => {
              let error = JsError.make(
                "Subprocess exited before ready signal (code: " ++
                code->Option.mapOr("null", c => Int.toString(c)) ++
                ", signal: " ++
                signal->Option.getOr("null") ++ ")",
              )
              reject(error)
              transport.readyReject := None
            }
          | None => Js.Console.error3("Received an error", code, signal)
          }
        }
      },
    ),
  )

  Bindings__ChildProcess.on(
    proc,
    #error(
      error => {
        if !transport.connected.contents {
          switch transport.readyReject.contents {
          | Some(reject) => {
              reject(error)
              transport.readyReject := None
            }
          | None => ()
          }
        }
      },
    ),
  )

  transport
}

let onMessage = (transport, handler) => {
  let _ = transport.messageHandlers->Array.push(handler)
}

let onError = (transport, handler) => {
  let _ = transport.errorHandlers->Array.push(handler)
}

let connect = async transport => {
  // Wait for ready signal from subprocess
  await Promise.make((resolve, reject) => {
    if transport.connected.contents {
      // Already ready (unlikely but possible)
      resolve()
    } else {
      // Store resolve/reject to be called when ready signal arrives
      transport.readyResolve := Some(() => resolve())
      transport.readyReject := Some(error => reject(error))
    }
  })
}

let disconnect = async transport => {
  transport.connected := false
  transport.messageBuffer := []
  transport.readyResolve := None
  transport.readyReject := None
}

let isConnected = transport => transport.connected.contents
