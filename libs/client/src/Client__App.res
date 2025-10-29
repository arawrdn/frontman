@react.component
let make = () => {
  let currentUrl =
    WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.href->WebAPI.URL.make(~url=_)
  let originUrl = `${currentUrl.protocol}//${currentUrl.host}`

  <div className="flex h-screen w-screen">
    <div className="w-1/2 h-full border-r flex flex-col">
      <Client__Chatbox />
    </div>
    <div className="grow h-full p-4">
      <AIElements.WebPreview defaultUrl={originUrl}>
        <AIElements.WebPreviewNavigation>
          <AIElements.WebPreviewUrl />
        </AIElements.WebPreviewNavigation>
        <AIElements.WebPreviewBody />
      </AIElements.WebPreview>
    </div>
  </div>
}
