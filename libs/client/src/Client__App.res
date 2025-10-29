module AIElements = Bindings__AIElements
module RadixUI__Icons = Bindings__RadixUI__Icons

@react.component
let make = () => {
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  let originUrl = `${currentUrl.protocol}//${currentUrl.host}`

  <div className="flex h-screen w-screen dark bg-background text-foreground">
    <div className="h-full border-r flex flex-col">
      <Client__Chatbox />
    </div>
    <div className="grow h-full p-4">
      <Client__WebPreview url={originUrl} />
    </div>
  </div>
}
