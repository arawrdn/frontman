@react.component
let make = (~url) => {
  let iframeRef: React.ref<Nullable.t<Dom.element>> = React.useRef(Nullable.null)

  let onLoad = React.useCallback((_e: JsxEvent.Image.t) => {
    iframeRef.current
    ->Nullable.toOption
    ->Option.forEach(iframe => {
      WebAPI.HTMLIFrameElement.contentDocument(iframe->Obj.magic)
      ->Null.toOption
      ->Option.forEach(
        doc => {
          Client__State.Actions.setPreviewDocument(~document=Some(doc))
        },
      )
    })
  }, [])

  <div className="flex-1">
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
          Client__State.Actions.setPreviewDocument(~document=None)
        })
      })}
    />
  </div>
}
