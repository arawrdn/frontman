@react.component
let make = (~element: WebAPI.DOMAPI.element, ~scrollTimestamp: float) => {
  let (rect, setRect) = React.useState(() => None)

  React.useEffect2(() => {
    let boundingRect = WebAPI.Element.getBoundingClientRect(element)
    setRect(_ => Some(boundingRect))
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
        border: "2px solid #3B82F6",
        pointerEvents: "none",
        zIndex: "9999",
      }
    />
  })
  ->Option.getOr(React.null)
}

