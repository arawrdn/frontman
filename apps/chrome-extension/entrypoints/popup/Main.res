%%raw("import './style.css'")

WebAPI.Global.document->WebAPI.Document.addEventListener(Custom("DOMContentLoaded"), _event => {
  let rootElement = WebAPI.Global.document->WebAPI.Document.querySelector("#root")
  switch rootElement->Null.toOption {
  | Some(rootElement) =>
    let root = ReactDOM.Client.createRoot(rootElement->WebAPI.Element.asRescriptElement)
    root->ReactDOM.Client.Root.render(
      <React.StrictMode>
        <App />
      </React.StrictMode>,
    )
  | None => ()
  }
})

