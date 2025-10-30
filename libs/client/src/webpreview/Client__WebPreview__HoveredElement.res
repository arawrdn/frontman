@react.component
let make = (~element: option<Null.t<WebAPI.EventAPI.eventTarget>>, ~scrollTimestamp: float) => {
  let (rect, setRect) = React.useState(() => None)

  React.useEffect2(() => {
    element
    ->Option.flatMap(Null.toOption)
    ->Option.forEach(target => {
      let element = WebAPI.EventTarget.asElement(target)
      let boundingRect = WebAPI.Element.getBoundingClientRect(element)
      setRect(_ => Some(boundingRect))
    })
    None
  }, (element, scrollTimestamp))

  rect
  ->Option.map(rect => {
    <div
      style={
        position: "absolute",
        left: `${Float.toString(rect.left)}px`,
        top: `${Float.toString(rect.top)}px`,
        width: `${Float.toString(rect.width)}px`,
        height: `${Float.toString(rect.height)}px`,
        backgroundColor: "rgba(255, 255, 0, 0.3)",
        pointerEvents: "none",
        zIndex: "9998",
      }
    />
  })
  ->Option.getOr(React.null)
}

