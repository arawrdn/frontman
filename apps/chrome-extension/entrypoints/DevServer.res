let main = () => {
  // WebAPI.Global.window->WebAPI.Window.addEventListener(Custom(("FrontmanImportFigmaNodeRequest")), (e) => {
  //   Console.log("FrontmanImportFigmaNodeRequest")
  //   Chrome.Runtime.sendMessageExternal("kfdpjbmabcelpgoipaccjijhehdmeghp", {"type": "DevServerImportFigmaNodeRequest"}, response => {
  //     Console.log2("DevServerImportFigmaNodeRequest response:", response)
  //   })
  // })

  // Chrome.Runtime.addMessageExternalListener((message, _sender, _sendResponse) => {
  //   let messageType = message["type"]
  //   switch messageType {
  //   | "DevServerImportFigmaNodeResponse" =>
  //     Console.log2("DevServerImportFigmaNodeResponse:", message["selectedFigmaNode"])
  //     let customEvent = CustomEvent.make(~detail=message["selectedFigmaNode"], ~bubbles=true, ~cancelable=true)
  //     WebAPI.Global.window->WebAPI.Window.postMessage(Custom(("FrontmanImportFigmaNodeResponse")), message["selectedFigmaNode"])
  //   | _ => ()
  //   }
  // })
  ()
}

let config = {
    "matches": ["http://localhost/*"],
}