@react.component
let make = (~document) => {
  let document = Some(document)
  let webPreviewIsSelecting = Client__State.useSelector(Client__State.Selectors.webPreviewIsSelecting)
  let selectedElement = Client__State.useSelector(Client__State.Selectors.selectedElement)
  
  let lastProcessedClick = React.useRef(None)
  
  let scrollTimestamp = Client__Hooks.Scroll.useIFrameDocument(~document, ~withCapture=true, ())
  
  let clickedElement = Client__Hooks.MouseClick.useIFrameDocument(
    ~document,
    ~withCapture=false,
    (),
  )

  let hoveredElement = Client__Hooks.MouseMove.useIFrameDocument(
    ~document,
    ~withCapture=true,
    (),
  )

  // Mark current click as processed when entering selection mode to ignore clicks from before selection mode
  React.useEffect1(() => {
    if webPreviewIsSelecting {
      // Mark the current clickedElement as already processed so we don't process clicks that happened before entering selection mode
      lastProcessedClick.current = clickedElement
    }
    None
  }, [webPreviewIsSelecting])

  React.useEffect2(() => {
    Console.log4("Effect running - webPreviewIsSelecting:", webPreviewIsSelecting, "clickedElement:", clickedElement)
    if webPreviewIsSelecting {
      clickedElement->Option.forEach(((target, _event)) => {
        // Check if this is a new click (different from last processed)
        let isNewClick = switch (lastProcessedClick.current, clickedElement) {
        | (Some(lastClick), Some(currentClick)) => lastClick !== currentClick
        | (None, Some(_)) => true
        | _ => false
        }
        
        if !isNewClick {
            ()
        } else {
          lastProcessedClick.current = clickedElement
          switch target {
          | Some(eventTarget) => {
              let element = WebAPI.EventTarget.asElement(eventTarget)
              Console.log2("Processing element click:", element)
            
            // Store initial element data
            Client__State.Actions.setSelectedElement(~selectedElement=Some({
              element: element,
              selector: None,
              screenshot: None,
              sourceLocation: None,
            }))
            
            // Use refs to accumulate data as it comes in
            let selectorRef = ref(None)
            let screenshotRef = ref(None)
            let sourceLocationRef = ref(None)
            
            let updateState = () => {
              Client__State.Actions.setSelectedElement(~selectedElement=Some({
                element: element,
                selector: selectorRef.contents,
                screenshot: screenshotRef.contents,
                sourceLocation: sourceLocationRef.contents,
              }))
            }
            
            // Fetch selector
            let _ = Promise.resolve()->Promise.then(_ => {
              let selector = Bindings__Finder.finder(
                ~element,
                ~options={
                  root: document->Option.map(doc => 
                    doc.documentElement->Obj.magic
                  )->Option.getOr(element),
                  idName: (~name as _) => true,
                  className: (~name as _) => true,
                  tagName: (~name as _) => true,
                  attr: (~name as _, ~value as _) => false,
                }
              )
              selectorRef.contents = Some(selector)
              updateState()
              Promise.resolve()
            })
            
            // Fetch screenshot
            let _ = Bindings__Snapdom.snapdom(~element)
              ->Promise.then(captureResult => {
                screenshotRef.contents = Some(captureResult.url)
                updateState()
                Promise.resolve()
              })
              ->Promise.catch(error => {
                Console.error2("Failed to capture screenshot:", error)
                Promise.resolve()
              })
            
            // Fetch source location
            let _ = Bindings__DOMElementToComponentSource.getElementSourceLocation(~element)
              ->Promise.then(sourceLocationOpt => {
                sourceLocationOpt->Option.forEach(sourceLocation => {
                  sourceLocationRef.contents = Some(sourceLocation)
                  updateState()
                })
                Promise.resolve()
              })
              ->Promise.catch(error => {
                Console.error2("Failed to get source location:", error)
                Promise.resolve()
              })
            }
          | None => Console.log("Element clicked: unknown")
          }
        }
      })
    }
    None
  }, (clickedElement, webPreviewIsSelecting))

  <div className="pointer-events-none flex-1 absolute top-0 left-0 w-full h-full">
    {webPreviewIsSelecting 
      ? <Client__WebPreview__HoveredElement key="hover" element={hoveredElement} scrollTimestamp={scrollTimestamp} />
      : React.null
    }
    {selectedElement->Option.mapOr(
      React.null,
      data => <Client__WebPreview__ClickedElement key="clicked" element={Some((Some(data.element->Obj.magic), ()))} scrollTimestamp={scrollTimestamp} />
    )}
  </div>
}