module Icons = Bindings__RadixUI__Icons

@react.component
let make = () => {
  let selectedElement = Client__State.useSelector(Client__State.Selectors.selectedElement)

  switch selectedElement {
  | None => React.null
  | Some({element,selector, sourceLocation, _}) => {
      <div
        className="px-4 py-2 bg-blue-50 dark:bg-blue-950/20 border-b border-blue-200 dark:border-blue-800 text-sm"
      >
        <div className="flex items-start gap-2">
          <Icons.CubeIcon
            className="size-4 text-blue-600 dark:text-blue-400 mt-0.5 flex-shrink-0"
          />
          <div className="flex-grow min-w-0">
            <div className="flex items-center gap-2 flex-wrap">
              <span className="font-semibold text-blue-900 dark:text-blue-100">
                {React.string("Selected Element:")}
              </span>
              {selector->Option.mapOr(React.null, sel =>
                <code
                  className="text-xs bg-blue-100 dark:bg-blue-900/40 px-1.5 py-0.5 rounded text-blue-800 dark:text-blue-200 font-mono"
                >
                  {React.string(`${element.tagName->String.toLowerCase} ${sel}`)}
                </code>
              )}
            </div>
            {sourceLocation->Option.mapOr(React.null, loc =>
              <div className="flex items-center gap-2 text-xs text-blue-700 dark:text-blue-300 mt-1">
                <span className="font-semibold text-blue-900 dark:text-blue-100">
                  {React.string("React Component:")}
                </span>
                <code className="font-medium"> {React.string(`<${loc.componentName} />`)} </code>
              </div>
            )}
          </div>
          <button
            onClick={_ => Client__State.Actions.setSelectedElement(~selectedElement=None)}
            className="text-blue-600 dark:text-blue-400 hover:text-blue-800 dark:hover:text-blue-200 flex-shrink-0"
            title="Clear selection"
          >
            <Icons.Cross2Icon className="size-4" />
          </button>
        </div>
      </div>
    }
  }
}

