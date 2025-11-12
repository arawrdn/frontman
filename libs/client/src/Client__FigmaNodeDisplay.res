// Component for displaying the current selected Figma node state
module Icons = Bindings__RadixUI__Icons

@react.component
let make = () => {
  let figmaNode = Client__State.useSelector(Client__State.Selectors.figmaNode)
  let figmaNodeWaiting = Client__State.useSelector(Client__State.Selectors.figmaNodeWaiting)

  React.useEffect(() => {
    // Listen for incoming port connection from background
    let listener = (message: 'message) => {
      let type_ = message["type"]
      let data = message["selectedFigmaNode"]
      switch type_ {
      | "DevServerImportFigmaNodeResponse" =>
        Client__State.Actions.setFigmaNode(~figmaNode=data)
      | _ => ()
      }

    }
    let port = AskTheLlmBindings.Chrome.Runtime.Connect.connectExternal(
      "kfdpjbmabcelpgoipaccjijhehdmeghp",
      Some({name: "FigmaNodeDisplay"}),
    )

    AskTheLlmBindings.Chrome.Port.addMessageListener(port, listener)

    Some(
      () => {
        AskTheLlmBindings.Chrome.Port.removeMessageListener(port, listener)
      },
    )
  }, [])

  // Show waiting state if waiting
  if figmaNodeWaiting {
    <div
      className="flex items-center gap-2 p-3 bg-purple-50 border-t border-purple-200 text-sm text-purple-900"
    >
      <Icons.FigmaIcon style={{"width": "16px", "height": "16px"}} />
      <span className="font-medium"> {React.string("Waiting for Figma node selection...")} </span>
      <button
        className="ml-auto text-purple-600 hover:text-purple-800"
        onClick={_ => Client__State.Actions.clearFigmaNodeWaiting()}
      >
        <Icons.Cross2Icon style={{"width": "14px", "height": "14px"}} />
      </button>
    </div>
  } else {
    // Show selected node if available
    figmaNode->Option.mapOr(React.null, node => {
      <div
        className="flex items-center gap-2 p-3 bg-blue-50 border-t border-blue-200 text-sm text-blue-900"
      >
        <Icons.FigmaIcon style={{"width": "16px", "height": "16px"}} />
        <span className="font-medium"> {React.string(`Figma Node Selected: ${node.name}`)} </span>
        <button
          className="ml-auto text-blue-600 hover:text-blue-800"
          onClick={_ => Client__State.Actions.clearFigmaNode()}
        >
          <Icons.Cross2Icon style={{"width": "14px", "height": "14px"}} />
        </button>
      </div>
    })
  }
}
