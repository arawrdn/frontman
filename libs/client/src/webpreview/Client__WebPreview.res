module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

@react.component
let make = (~url) => {
  let fullscreen = React.useRef(false)

  let handleBack = () => Js.Console.log("Go back")
  let handleForward = () => Js.Console.log("Go forward")
  let handleReload = () => Js.Console.log("Reload")
  let handleSelect = () => Js.Console.log("Select")
  let handleOpenInNewTab = () => Js.Console.log("Open in new tab")
  let handleFullscreen = () => {
    fullscreen.current = !fullscreen.current
    Js.Console.log2("Fullscreen:", fullscreen.current)
  }
  <AIElements.WebPreview
    defaultUrl={url} onUrlChange={url => Js.Console.log2("URL changed to:", url)}
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
      <AIElements.WebPreviewNavigationButton onClick={handleSelect} tooltip="Select">
        <RadixUI__Icons.Crosshair1Icon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleOpenInNewTab} tooltip="Open in new tab">
        <RadixUI__Icons.OpenInNewWindowIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
      <AIElements.WebPreviewNavigationButton onClick={handleFullscreen} tooltip="Maximize">
        <RadixUI__Icons.EnterFullScreenIcon className="size-4" />
      </AIElements.WebPreviewNavigationButton>
    </AIElements.WebPreviewNavigation>
    <Client__WebPreview__Body url={url} />
  </AIElements.WebPreview>
}
