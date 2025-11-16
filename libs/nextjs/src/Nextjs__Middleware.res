module Core = Middleware__Core

//TODO(danni) - move all of these to our bindings folder
module NextResponse = {
  type t = WebAPI.FetchAPI.response
  type init = {
    status: int,
    headers?: WebAPI.FetchAPI.headersInit,
    statusText?: string,
  }

  @module("next/server") @scope("NextResponse")
  external json: (Js.t<'a>, ~init: init=?) => t = "json"
  @module("next/server") @scope("NextResponse")
  external next: unit => t = "next"
}

module NextRequest = {
  type t = WebAPI.FetchAPI.request
}

// Convert Nextjs__Config.t to Core.config
let configToCore = (config: Nextjs__Config.t): Core.config => {
  {
    isDev: config.isDev,
    basePath: config.basePath,
    clientUrl: config.clientUrl,
    clientCssUrl: config.clientCssUrl,
    entrypointUrl: config.entrypointUrl,
    isLightTheme: config.isLightTheme,
    projectRoot: config.projectRoot,
  }
}

let createMiddleware = (conf: Nextjs__Config.t) => {
  let coreConfig = configToCore(conf)
  let coreMiddleware = Core.createMiddleware(coreConfig)
  
  let middleware: NextRequest.t => Promise.t<NextResponse.t> = async (req: NextRequest.t) => {
    let result = await coreMiddleware(req)
    switch result {
    | Some(response) => response
    | None => NextResponse.next()
    }
  }
  middleware
}
