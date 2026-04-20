module Dialog = Bindings__UI__Dialog
module Button = Bindings__UI__Button

let bridgeSource = "frontman.auth-bridge"

type bridgeStatus =
  | Idle
  | Connecting
  | Error(string)

type authStrategy = Redirect | Popup

let shouldAutoStartAuth = (~authStrategy, ~ftueState) => {
  switch (authStrategy, ftueState) {
  | (Redirect, Client__FtueState.WelcomeShown | Client__FtueState.Completed) => true
  | _ => false
  }
}

@schema
type bridgeMessage = {
  source: string,
  kind: string,
  token: option<string>,
  message: option<string>,
}

let bridgeStatusMessage = (
  status: bridgeStatus,
  ftueState: Client__FtueState.t,
  authStrategy: authStrategy,
): string =>
  switch (status, ftueState, authStrategy) {
  | (
      Idle,
      Client__FtueState.New,
      Redirect,
    ) => "Your AI-powered coding assistant is ready. Sign in to Frontman and we will bring you right back here automatically once sign-in completes."
  | (
      Idle,
      Client__FtueState.WelcomeShown | Client__FtueState.Completed,
      Redirect,
    ) => "Sign in to Frontman and we will bring you right back here automatically once sign-in completes."
  | (
      Idle,
      Client__FtueState.New,
      Popup,
    ) => "Your AI-powered coding assistant is ready. Sign in to Frontman in a popup window and we will reconnect your session here automatically once sign-in completes."
  | (
      Idle,
      Client__FtueState.WelcomeShown | Client__FtueState.Completed,
      Popup,
    ) => "Sign in to Frontman in a popup window. We will reconnect your session here automatically once sign-in completes."
  | (Connecting, _, _) => "Session connected. Finishing secure handshake..."
  | (Error(message), _, _) => message
  }

let popupLoginUrl = (~loginUrl: string, ~authBridgeUrl: string): string => {
  let login = WebAPI.URL.make(~url=loginUrl)
  let popupReturn = WebAPI.URL.make(~url=authBridgeUrl)
  popupReturn.searchParams->WebAPI.URLSearchParams.set(~name="popup", ~value="1")
  popupReturn.searchParams->WebAPI.URLSearchParams.set(
    ~name="opener_origin",
    ~value=WebAPI.Global.origin,
  )
  login.searchParams->WebAPI.URLSearchParams.set(~name="return_to", ~value=popupReturn.href)
  login.href
}

let detectAuthStrategy = (): authStrategy => {
  let userAgent = WebAPI.Global.navigator.userAgent
  let isFirefox = String.includes(userAgent, "Firefox/") || String.includes(userAgent, "FxiOS/")
  let isChromiumEngine =
    String.includes(userAgent, "Chrome/") ||
    String.includes(userAgent, "Chromium/") ||
    String.includes(userAgent, "Edg/") ||
    String.includes(userAgent, "OPR/")

  if isChromiumEngine && !isFirefox && !String.includes(userAgent, "CriOS/") {
    Redirect
  } else {
    Popup
  }
}

@react.component
let make = (
  ~loginUrl: string,
  ~authBridgeUrl: string,
  ~ftueState: Client__FtueState.t,
  ~onWelcomeShown: unit => unit,
  ~onBridgeToken: string => unit,
) => {
  let (bridgeStatus, setBridgeStatus) = React.useState(() => Idle)
  let authStrategy = detectAuthStrategy()
  let bridgeOrigin = WebAPI.URL.make(~url=authBridgeUrl).origin
  let popupUrl = popupLoginUrl(~loginUrl, ~authBridgeUrl)

  let openPopupAuth = () => {
    setBridgeStatus(_ => Idle)
    WebAPI.Window.open_(
      WebAPI.Global.window,
      ~url=popupUrl,
      ~target="frontman-auth-popup",
      ~features="popup=yes,width=560,height=740,resizable=yes,scrollbars=yes",
    )->ignore
  }

  let startAuth = () => {
    switch authStrategy {
    | Redirect => WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(loginUrl)
    | Popup => openPopupAuth()
    }
  }

  React.useEffect(() => {
    switch ftueState {
    | Client__FtueState.New => onWelcomeShown()
    | Client__FtueState.WelcomeShown | Client__FtueState.Completed => ()
    }
    None
  }, (ftueState, onWelcomeShown))

  React.useEffect2(() => {
    if shouldAutoStartAuth(~authStrategy, ~ftueState) {
      startAuth()
    }
    None
  }, (authStrategy, ftueState))

  React.useEffect2(() => {
    if authStrategy == Redirect {
      None
    } else {
      let handleMessage = (event: WebAPI.WebSocketsAPI.messageEvent<JSON.t>) => {
        if event.origin == bridgeOrigin {
          switch event.data->JSON.Decode.string {
          | Some(rawPayload) =>
            try {
              let payload = rawPayload->JSON.parseOrThrow->S.parseOrThrow(bridgeMessageSchema)
              if payload.source == bridgeSource {
                switch payload.kind {
                | "token" =>
                  switch payload.token {
                  | Some(token) =>
                    setBridgeStatus(_ => Connecting)
                    onBridgeToken(token)
                  | None =>
                    setBridgeStatus(_ => Error("Frontman session bridge returned an empty token."))
                  }
                | "error" =>
                  setBridgeStatus(_ => Error(
                    payload.message->Option.getOr("Failed to connect session."),
                  ))
                | _ => ()
                }
              }
            } catch {
            | _ => ()
            }
          | None => ()
          }
        }
      }

      WebAPI.Global.window->WebAPI.Window.addEventListener(Message, handleMessage)

      Some(
        () => {
          WebAPI.Global.window->WebAPI.Window.removeEventListener(Message, handleMessage)
        },
      )
    }
  }, (authStrategy, bridgeOrigin))

  let heading = switch ftueState {
  | Client__FtueState.New => "Welcome to Frontman!"
  | Client__FtueState.WelcomeShown | Client__FtueState.Completed => "Reconnect Frontman"
  }

  <Dialog.Dialog open_={true} onOpenChange={_ => ()}>
    <Dialog.DialogContent
      className="sm:max-w-lg max-w-lg border-zinc-700 bg-zinc-900 p-0" showCloseButton={false}
    >
      <div className="px-8 py-10 text-center">
        <div className="mx-auto mb-6">
          <Client__FrontmanLogo size=48 />
        </div>

        <Dialog.DialogTitle className="text-xl font-bold text-zinc-100">
          {React.string(heading)}
        </Dialog.DialogTitle>

        <Dialog.DialogDescription className="mt-3 text-sm leading-relaxed text-zinc-400">
          {React.string(bridgeStatusMessage(bridgeStatus, ftueState, authStrategy))}
        </Dialog.DialogDescription>

        <div className="mt-6 flex justify-center">
          <Button.Button
            className="min-w-40" disabled={bridgeStatus == Connecting} onClick={_ => startAuth()}
          >
            {React.string("Sign in")}
          </Button.Button>
        </div>
      </div>
    </Dialog.DialogContent>
  </Dialog.Dialog>
}
