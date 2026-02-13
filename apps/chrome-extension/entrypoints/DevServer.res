let main = () => {
  WebAPI.Global.document->WebAPI.Document.body->Null.toOption->Option.forEach(body => {
    body->WebAPI.Element.classList->WebAPI.DOMTokenList.add("frontman-extension-active")
    ()
  })
  ()
}

let config = {
    "matches": ["http://localhost/*"],
 }