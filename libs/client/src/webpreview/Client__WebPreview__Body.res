@react.component
let make = (~url) => {
  let isSelecting = Client__State.useSelector(Client__State.Selectors.webPreviewIsSelecting)
  let iframeRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)
  let location = Client__Hooks.useIFrameLocation(~iframeRef=iframeRef.current->Obj.magic)
  Client__Hooks.useDisableIFrameAnchorPointerEvents(~iframeRef=iframeRef.current->Obj.magic, ~activate=isSelecting)
  React.useEffect(() => {
    switch location {
    | Some(location) => 
      Client__State.Actions.setPreviewUrl(~url=location)
      Client__State.Actions.setSelectedElement(~selectedElement=None)
    | None => ()
    }
    None
  }, [location])

  let onLoad = React.useCallback((_e: JsxEvent.Image.t) => {
    iframeRef.current
    ->Nullable.toOption
    ->Option.forEach(iframe => {
      let iframeElement = iframe->Obj.magic
      let contentDocument = WebAPI.HTMLIFrameElement.contentDocument(iframeElement)->Null.toOption
      let contentWindow = WebAPI.HTMLIFrameElement.contentWindow(iframeElement)->Null.toOption
      
      Client__State.Actions.setPreviewFrame(
        ~contentDocument,
        ~contentWindow,
      )
    })
  }, [])

  <div className="flex-1 size-full">
    <iframe
      className={"size-full"}
      sandbox="allow-scripts allow-same-origin allow-forms allow-popups allow-presentation"
      src={url}
      title="Preview"
      onLoad={onLoad}
      ref={ReactDOM.Ref.callbackDomRef(iframe => {
        iframeRef.current = iframe
        Some(() => {
          iframeRef.current = Nullable.null
        })
      })}
    />
  </div>
}
