// Transport module type signature
module type Interface = {
  type t
  type config

  let make: config => t

  // Send a message through the transport
  let send: (t, string) => promise<unit>

  // Register a handler for incoming messages
  let onMessage: (t, string => unit) => unit

  // Register a handler for transport errors
  let onError: (t, JsError.t => unit) => unit

  // Connect/initialize the transport
  let connect: t => promise<unit>

  // Disconnect/cleanup the transport
  let disconnect: t => promise<unit>

  // Check if transport is connected
  let isConnected: t => bool
}
