module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

@react.component
let make = (~url) => {
  let previewDocument = Client__State.useSelector(Client__State.Selectors.previewDocument)
  let webPreviewIsSelecting = Client__State.useSelector(Client__State.Selectors.webPreviewIsSelecting)
  let fullscreen = React.useRef(false)

  let handleBack = () => ()
  let handleForward = () => ()
  let handleReload = () => ()
  let handleSelect = () => Client__State.Actions.toggleWebPreviewSelection()
  let handleOpenInNewTab = () => ()
  let handleFullscreen = () => {
    fullscreen.current = !fullscreen.current
  }
  <AIElements.WebPreview
    defaultUrl={url} onUrlChange={_ => ()}
  >
    <AIElements.WebPreviewNavigation>
      <AIElements.WebPreviewNavigationButton onClick={handleBack} tooltip="Go back">
        <RadixUI__Icons.ArrowLeftIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleForward} tooltip="Go forward">
        <RadixUI__Icons.ArrowRightIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleReload} tooltip="Reload">
        <RadixUI__Icons.ReloadIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewUrl />
      <div className={webPreviewIsSelecting ? "rounded bg-blue-500/20" : ""}>
        <AIElements.WebPreviewNavigationButton 
          onClick={handleSelect} 
          tooltip="Select"
        >
          <RadixUI__Icons.Crosshair1Icon className={webPreviewIsSelecting ? "size-4 text-blue-500" : "size-4"} />
        </AIElements.WebPreviewNavigationButton>
      </div>
      <AIElements.WebPreviewNavigationButton onClick={handleOpenInNewTab} tooltip="Open in new tab">
        <RadixUI__Icons.OpenInNewWindowIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleFullscreen} tooltip="Maximize">
        <RadixUI__Icons.EnterFullScreenIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
    </AIElements.WebPreviewNavigation>
    
    <div className="relative size-full">
      {switch previewDocument.document {
      | Some(document) => <Client__WebPreview__Stage document={document} />
      | None => React.null
      }}

      <Client__WebPreview__Body url={url} />
    </div>
  </AIElements.WebPreview>
}
