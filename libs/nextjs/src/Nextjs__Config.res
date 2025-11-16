module Bindings = AskTheLlmBindings
type t = {
  isDev: bool,
  basePath: string,
  clientUrl: string,
  clientCssUrl: option<string>,
  entrypointUrl: option<string>,
  isLightTheme: bool,
  projectRoot: string,
}

let make = (~isDev=None, ~basePath=None, ~clientUrl=None, ~clientCssUrl=None, ~entrypointUrl=None, ~isLightTheme=None) => {
  let isDev =
    isDev->Option.getOr(
      Bindings.Process.env->Dict.get("NODE_ENV")->Option.getOr("production") == "development",
  )
  let basePath = basePath->Option.getOr("ask-the-llm")
  let isLightTheme = isLightTheme->Option.getOr(false)

  let projectRoot =
    Bindings.Process.env
    ->Dict.get("PROJECT_ROOT")
    ->Option.orElse(Bindings.Process.env->Dict.get("PWD"))
    ->Option.getOr(".")
  
  let clientUrl = clientUrl->Option.getOr(
    switch isDev {
    | true => "http://localhost:5173/src/Main.res.mjs"
    | false => "https://ask-the-llm.vercel.app/ask-the-llm.es.js"
    }
  )
  
  {
    isDev,
    clientUrl,
    clientCssUrl,
    entrypointUrl,
    isLightTheme,
    basePath,
    projectRoot,
  }
}
