let storageKeyPrefix = "frontman:auth-session-token:"

// Tokens are keyed by origin only, so callers may pass either the auth bridge URL
// or the API base URL as long as they share the same origin.
let storageKey = (originUrl: string): string => {
  let origin = WebAPI.URL.make(~url=originUrl).origin
  `${storageKeyPrefix}${origin}`
}

let get = (originUrl: string): option<string> => {
  try {
    WebAPI.Global.sessionStorage
    ->WebAPI.Storage.getItem(storageKey(originUrl))
    ->Null.toOption
  } catch {
  | _ => None
  }
}

let set = (~originUrl: string, ~token: string): unit => {
  try {
    WebAPI.Global.sessionStorage->WebAPI.Storage.setItem(~key=storageKey(originUrl), ~value=token)
  } catch {
  | _ => ()
  }
}

let clear = (originUrl: string): unit => {
  try {
    WebAPI.Global.sessionStorage->WebAPI.Storage.removeItem(storageKey(originUrl))
  } catch {
  | _ => ()
  }
}
