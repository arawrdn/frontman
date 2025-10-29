let exampleLogs: array<AIElements.consoleLog> = [
  {
    level: #log,
    message: "Page loaded successfully",
    timestamp: Js.Date.make()->Js.Date.valueOf->(v => v -. 10000.0)->Js.Date.fromFloat,
  },
  {
    level: #warn,
    message: "Deprecated API usage detected",
    timestamp: Js.Date.make()->Js.Date.valueOf->(v => v -. 5000.0)->Js.Date.fromFloat,
  },
  {
    level: #error,
    message: "Failed to load resource",
    timestamp: Js.Date.make(),
  },
]

@react.component
let make = () => {
  let url = AskTheLlm.useSelector(AskTheLlm.Selectors.url)
  Console.log2("URL:", url)
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  let originUrl = `${currentUrl.protocol}//${currentUrl.host}`
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

  <div className="flex h-screen w-screen dark bg-background text-foreground">
    <div className="h-full border-r flex flex-col">
      <Client__Chatbox />
    </div>
    <div className="grow h-full p-4">
      <AIElements.WebPreview
        defaultUrl={originUrl} onUrlChange={url => Js.Console.log2("URL changed to:", url)}
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
          <AIElements.WebPreviewNavigationButton
            onClick={handleOpenInNewTab} tooltip="Open in new tab"
          >
            <RadixUI__Icons.OpenInNewWindowIcon className="size-4" />
          </AIElements.WebPreviewNavigationButton>
          <AIElements.WebPreviewNavigationButton onClick={handleFullscreen} tooltip="Maximize">
            <RadixUI__Icons.EnterFullScreenIcon className="size-4" />
          </AIElements.WebPreviewNavigationButton>
        </AIElements.WebPreviewNavigation>
        <AIElements.WebPreviewBody />
        <AIElements.WebPreviewConsole logs={exampleLogs} />
      </AIElements.WebPreview>
    </div>
  </div>
}
