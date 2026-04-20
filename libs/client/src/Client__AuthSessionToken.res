let storageKeyPrefix = "frontman:auth-session-token:"

let storageKey = (authBridgeUrl: string): string => {
  let origin = WebAPI.URL.make(~url=authBridgeUrl).origin
  `${storageKeyPrefix}${origin}`
}

let get = (authBridgeUrl: string): option<string> => {
  try {
    WebAPI.Global.sessionStorage
    ->WebAPI.Storage.getItem(storageKey(authBridgeUrl))
    ->Null.toOption
  } catch {
  | _ => None
  }
}

let set = (~authBridgeUrl: string, ~token: string): unit => {
  try {
    WebAPI.Global.sessionStorage->WebAPI.Storage.setItem(
      ~key=storageKey(authBridgeUrl),
      ~value=token,
    )
  } catch {
  | _ => ()
  }
}

let clear = (authBridgeUrl: string): unit => {
  try {
    WebAPI.Global.sessionStorage->WebAPI.Storage.removeItem(storageKey(authBridgeUrl))
  } catch {
  | _ => ()
  }
}
