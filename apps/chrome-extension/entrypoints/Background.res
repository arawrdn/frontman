open AskTheLlmBindings

module ImportFigmaNodeRequest = {
  type t = {tabId: int}

  let make = (~tabId: int) => {
    {
      tabId: tabId,
    }
  }
}

let main = () => {
  let importFigmaNodeRequest: ref<option<ImportFigmaNodeRequest.t>> = ref(None)
  let figmaNodeDisplayPort: ref<option<Chrome.port<'message>>> = ref(None)
  // Listen for messages on this port
  Chrome.Runtime.Connect.addConnectExternalListener("kfdpjbmabcelpgoipaccjijhehdmeghp", port => {
    Console.log2("[Background] Message received from FigmaNodeDisplay port:", port)
    figmaNodeDisplayPort := Some(port)
    Chrome.Port.addMessageListener(port, message => {
      Console.log2("[Background] Message received from FigmaNodeDisplay port:", message)
    })
    // Handle port disconnect
    Chrome.Runtime.Connect.addDisconnectListener(port, _port => {
      Console.log("[Background] FigmaNodeDisplay port disconnected")
      figmaNodeDisplayPort := None
    })
  })

  let runtimeId = %raw(`chrome.runtime.id`)
  Console.log2("Browser runtime ID:", runtimeId)

  Chrome.Runtime.addMessageExternalListener((message, sender, sendResponse) => {
    let messageType = %raw(`message.type`)

    switch messageType {
    | "FigmaNodeDisplayHandshake" =>
      Console.log2("[Background] Received FigmaNodeDisplayHandshake from tab:", sender.tab.id)
      sendResponse({"success": true})

    | "FigmaNodeSelected" =>
      Console.log2("[Background] Received FigmaNodeSelected message:", message)

      // Send to the dev server tab if we have a request
      switch importFigmaNodeRequest.contents {
      | Some(_request) =>
        let msg = {
          "type": "DevServerImportFigmaNodeResponse",
          "selectedFigmaNode": message["selectedFigmaNode"],
        }

        // Also send through the FigmaNodeDisplay port if connected
        figmaNodeDisplayPort.contents->Option.forEach(port => {
          Console.log("[Background] Sending to FigmaNodeDisplay port")
          port.postMessage(msg)
        })
      | None => ()
      }

    | "DevServerImportFigmaNodeRequest" =>
      Console.log2("[Background] Received DevServerImportFigmaNodeRequest message:", message)
      importFigmaNodeRequest := Some(ImportFigmaNodeRequest.make(~tabId=sender.tab.id))
    | _ => ()
    }
  })
}
