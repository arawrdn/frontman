let redirectStorageKey = "frontman:auth_redirect_started_at"
let redirectWindowMs = 5. *. 60_000.

type browser =
  | Safari
  | Chrome
  | Firefox
  | Edge
  | Unknown

let currentOrigin = (): string => {
  let location = WebAPI.Global.location
  `${location.protocol}//${location.host}`
}

let browserFromUserAgent = (userAgent: string): browser => {
  let ua = userAgent->String.toLowerCase

  switch () {
  | _ when ua->String.includes("edg") => Edge
  | _ when ua->String.includes("firefox") || ua->String.includes("fxios") => Firefox
  | _ when ua->String.includes("chrome") || ua->String.includes("crios") || ua->String.includes("chromium") => Chrome
  | _ when ua->String.includes("safari") => Safari
  | _ => Unknown
  }
}

let currentBrowser = (): browser => WebAPI.Global.navigator.userAgent->browserFromUserAgent

let isCrossSiteLogin = (~loginUrl: string): bool => {
  try {
    WebAPI.URL.make(~url=loginUrl).origin != currentOrigin()
  } catch {
  | _ => false
  }
}

let recordLoginRedirect = () => {
  try {
    FrontmanBindings.LocalStorage.setItem(redirectStorageKey, Js.Date.now()->Float.toString)
  } catch {
  | _ => ()
  }
}

let clearLoginRedirect = () => {
  try {
    FrontmanBindings.LocalStorage.removeItem(redirectStorageKey)
  } catch {
  | _ => ()
  }
}

let hasRecentLoginRedirect = (): bool => {
  try {
    switch FrontmanBindings.LocalStorage.getItem(redirectStorageKey)->Nullable.toOption {
    | Some(value) =>
      switch value->Float.fromString {
      | Some(timestamp) => Js.Date.now() -. timestamp <= redirectWindowMs
      | None => false
      }
    | None => false
    }
  } catch {
  | _ => false
  }
}

let shouldShowNotice = (~loginUrl: string): bool => {
  switch isCrossSiteLogin(~loginUrl) {
  | false => false
  | true =>
    switch (currentBrowser(), hasRecentLoginRedirect()) {
    | (Safari, _) => true
    | (_, true) => true
    | (_, false) => false
    }
  }
}

let continueToLogin = (~loginUrl: string) => {
  recordLoginRedirect()
  WebAPI.Global.window->WebAPI.Window.location->WebAPI.Location.assign(loginUrl)
}
