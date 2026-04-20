// If you want to use Phoenix channels, run `mix help phx.gen.channel`
// to get started and then uncomment the line below.
// import "./user_socket.js"

// You can include dependencies in two ways.
//
// The simplest option is to put them in assets/vendor and
// import them using relative paths:
//
//     import "../vendor/some-package.js"
//
// Alternatively, you can `npm install some-package --prefix assets` and import
// them using a path starting with the package name:
//
//     import "some-package"
//
// If you have dependencies that try to import CSS, esbuild will generate a separate `app.css` file.
// To load it, simply add a second `<link>` to your `root.html.heex` file.

// Include phoenix_html to handle method=PUT/DELETE in forms and buttons.
import "phoenix_html"
// Establish Phoenix Socket and LiveView configuration.
import {Socket} from "phoenix"
import {LiveSocket} from "phoenix_live_view"
import {hooks as colocatedHooks} from "phoenix-colocated/frontman_server"
import topbar from "../vendor/topbar"

const csrfToken = document.querySelector("meta[name='csrf-token']").getAttribute("content")
const liveSocket = new LiveSocket("/live", Socket, {
  longPollFallbackMs: 2500,
  params: {_csrf_token: csrfToken},
  hooks: {...colocatedHooks},
})

// Show progress bar on live navigation and form submits
topbar.config({barColors: {0: "#29d"}, shadowColor: "rgba(0, 0, 0, .3)"})
window.addEventListener("phx:page-loading-start", _info => topbar.show(300))
window.addEventListener("phx:page-loading-stop", _info => topbar.hide())

// connect if there are any LiveViews on the page
liveSocket.connect()

// Auto-submit forms marked with data-auto-submit (used by the logout interstitial)
document.querySelectorAll("form[data-auto-submit]").forEach(form => {
  form.requestSubmit()
})

// expose liveSocket on window for web console debug logs and latency simulation:
// >> liveSocket.enableDebug()
// >> liveSocket.enableLatencySim(1000)  // enabled for duration of browser session
// >> liveSocket.disableLatencySim()
window.liveSocket = liveSocket

const AUTH_BRIDGE_SOURCE = "frontman.auth-bridge"

function initAuthBridge(root) {
  const currentUrl = new URL(window.location.href)
  const popupMode = currentUrl.searchParams.get("popup") === "1"
  const openerOrigin = currentUrl.searchParams.get("opener_origin")
  const status = root.querySelector("#auth-bridge-status")

  if (!status) {
    return
  }

  let parentOrigin = null
  if (popupMode && openerOrigin) parentOrigin = openerOrigin

  const postToParent = payload => {
    const targetWindow = popupMode ? window.opener : window.parent

    if (!parentOrigin || !targetWindow || targetWindow === window) {
      return
    }

    targetWindow.postMessage(JSON.stringify({source: AUTH_BRIDGE_SOURCE, ...payload}), parentOrigin)
  }

  const setStatus = message => {
    status.textContent = message
  }

  const errorMessage = err => {
    if (err instanceof Error && err.message) {
      return err.message
    }

    return "Unable to connect your Frontman session."
  }

  const fetchToken = async () => {
    const response = await fetch("/api/socket-token", {
      credentials: "include",
    })

    if (response.ok) {
      const json = await response.json()
      if (typeof json.token === "string") {
        postToParent({kind: "token", token: json.token})

        if (popupMode) {
          window.close()
        }

        return
      }

      throw new Error("Auth bridge returned an invalid token payload")
    }

    if (response.status === 401) {
      if (popupMode) {
        setStatus("Sign in did not complete in this window. Please try again.")
        postToParent({kind: "error", message: "Sign in did not complete in this window."})
        return
      }

      setStatus("This secure page needs an active Frontman session before it can continue.")
      return
    }

    throw new Error(`Auth bridge token request failed (${response.status})`)
  }

  if (popupMode && openerOrigin) {
    setStatus("Completing sign-in in this secure window...")
    void fetchToken()
  } else {
    setStatus("This secure page is only used to hand sign-in back to Frontman.")
  }
}

const authBridgeRoot = document.querySelector("[data-auth-bridge-root]")
if (authBridgeRoot) {
  initAuthBridge(authBridgeRoot)
}

// The lines below enable quality of life phoenix_live_reload
// development features:
//
//     1. stream server logs to the browser console
//     2. click on elements to jump to their definitions in your code editor
//
if (process.env.NODE_ENV === "development") {
  window.addEventListener("phx:live_reload:attached", ({detail: reloader}) => {
    // Enable server log streaming to client.
    // Disable with reloader.disableServerLogs()
    reloader.enableServerLogs()

    // Open configured PLUG_EDITOR at file:line of the clicked element's HEEx component
    //
    //   * click with "c" key pressed to open at caller location
    //   * click with "d" key pressed to open at function component definition location
    let keyDown
    window.addEventListener("keydown", e => keyDown = e.key)
    window.addEventListener("keyup", e => keyDown = null)
    window.addEventListener("click", e => {
      if(keyDown === "c"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtCaller(e.target)
      } else if(keyDown === "d"){
        e.preventDefault()
        e.stopImmediatePropagation()
        reloader.openEditorAtDef(e.target)
      }
    }, true)

    window.liveReloader = reloader
  })
}
