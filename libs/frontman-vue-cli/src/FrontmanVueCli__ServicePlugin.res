// Vue CLI Service Plugin for Frontman
// Adapts Web API Request/Response to Express middleware (req, res, next)
// and injects annotation capture into the webpack build.

module Config = FrontmanVueCli__Config
module Middleware = FrontmanVueCli__Middleware
module Core = FrontmanFrontmanCore

// Minimal Express/Node.js http bindings

// IncomingMessage (readable stream of request data)
type incomingMessage = {
  method: Null.t<string>,
  url: Null.t<string>,
  headers: Dict.t<string>,
}

// ServerResponse (writable stream for response)
type serverResponse

@send external writeHead: (serverResponse, int, Dict.t<string>) => unit = "writeHead"
@send external write: (serverResponse, Uint8Array.t) => bool = "write"
@send external endResponse: serverResponse => unit = "end"
@send external endResponseWithData: (serverResponse, string) => unit = "end"
@set external setStatusCode: (serverResponse, int) => unit = "statusCode"

// Helper: convert WebAPI Headers to a Dict<string>
let headersToDict: WebAPI.FetchAPI.headers => Dict.t<string> = %raw(`
  function headersToDict(headers) {
    const dict = {};
    headers.forEach(function(value, key) {
      dict[key] = value;
    });
    return dict;
  }
`)

// Buffer (opaque type for Node.js Buffer which extends Uint8Array)
type nodeBuffer
@scope("Buffer") @val external bufferConcat: array<nodeBuffer> => nodeBuffer = "concat"
@get external bufferLength: nodeBuffer => int = "length"

// Helper: collect body chunks from IncomingMessage using for-await
let collectBody: incomingMessage => promise<nodeBuffer> = %raw(`
  async function collectBody(req) {
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    return Buffer.concat(chunks);
  }
`)

// Helper: pipe a ReadableStream to ServerResponse
let pipeStreamToResponse: (WebAPI.FileAPI.readableStream<'a>, serverResponse) => promise<unit> = %raw(`
  async function pipeStreamToResponse(stream, res) {
    const reader = stream.getReader();
    try {
      while (true) {
        const { done, value } = await reader.read();
        if (done) break;
        res.write(value);
      }
    } finally {
      reader.releaseLock();
    }
  }
`)

// Express middleware type: (req, res, next) => void
type expressMiddleware = (incomingMessage, serverResponse, unit => unit) => unit

// Vue CLI PluginAPI bindings
type expressApp
@send external useMiddleware: (expressApp, expressMiddleware) => unit = "use"

type webpackDevServer // opaque, not used directly

type webpackChainConfig
// webpack-chain API: config.plugin(name).use(Plugin, args)
type webpackChainPlugin
@send external chainPlugin: (webpackChainConfig, string) => webpackChainPlugin = "plugin"
@send @variadic external chainUse: (webpackChainPlugin, 'a, array<'b>) => unit = "use"

type vuecliApi = {
  configureDevServer: ((expressApp, webpackDevServer) => unit) => unit,
  chainWebpack: (webpackChainConfig => unit) => unit,
}

// Webpack EntryPlugin binding
type webpackEntryPlugin
@module("webpack") @new
external makeEntryPlugin: (string, string, {..}) => webpackEntryPlugin = "EntryPlugin"

// Node.js path/require bindings
@module("path") external dirname: string => string = "dirname"
@module("path") external resolve: (string, string) => string = "resolve"
@val external __dirname: string = "__dirname"

// JS-friendly options type for the plugin
type pluginOptions = {
  isDev?: bool,
  basePath?: string,
  clientUrl?: string,
  clientCssUrl?: string,
  entrypointUrl?: string,
  isLightTheme?: bool,
  projectRoot?: string,
  sourceRoot?: string,
  host?: string,
}

// Adapt Web API middleware to Express middleware
let adaptMiddlewareToExpress = (
  ~basePath: string,
  middleware: WebAPI.FetchAPI.request => promise<option<WebAPI.FetchAPI.response>>,
): ((incomingMessage, serverResponse, unit => unit) => promise<unit>) => {
  async (req, res, next) => {
    let reqUrl = req.url->Null.toOption->Option.getOr("/")
    let pathname = reqUrl->String.toLowerCase
    let pathOnly = switch pathname->String.indexOf("?") {
    | -1 => pathname
    | idx => pathname->String.slice(~start=0, ~end=idx)
    }
    let isFrontmanRoute = Core.FrontmanCore__Middleware.isFrontmanRoute(
      ~pathname=pathOnly,
      ~basePath,
      ~method=req.method->Null.toOption->Option.getOr("GET"),
    )
    switch isFrontmanRoute {
    | false => next()
    | true =>
      let bodyBuffer = await collectBody(req)

      let host = req.headers->Dict.get("host")->Option.getOr("localhost")
      let url = `http://${host}${reqUrl}`

      let method = req.method->Null.toOption->Option.getOr("GET")
      let headers = WebAPI.HeadersInit.fromDict(req.headers)
      let hasBody = bufferLength(bodyBuffer) > 0

      let body = switch hasBody {
      | true =>
        Some(WebAPI.BodyInit.fromArrayBuffer((Obj.magic(bodyBuffer): ArrayBuffer.t)))
      | false => None
      }

      let webRequest = WebAPI.Request.fromURL(url, ~init={method, headers, ?body})

      let responseOption = await middleware(webRequest)

      switch responseOption {
      | None => next()
      | Some(webResponse) =>
        setStatusCode(res, webResponse.status)

        let headerDict = headersToDict(webResponse.headers)
        writeHead(res, webResponse.status, headerDict)

        switch webResponse.body->Null.toOption {
        | Some(stream) => await pipeStreamToResponse(stream, res)
        | None => ()
        }

        endResponse(res)
      }
    }
  }
}

// Create the Vue CLI service plugin function
// Signature: (api, projectOptions) => void (Vue CLI convention)
let servicePlugin = (api: vuecliApi, projectOptions: {..}): unit => {
  let _ = projectOptions // Reserved for future options passthrough

  // Register dev server middleware
  api.configureDevServer((app, _devServer) => {
    // Initialize core LogCapture
    Core.FrontmanCore__LogCapture.initialize()

    // Create config
    let config = Config.makeFromObject({})
    let middleware = Middleware.createMiddleware(config)
    let adaptedMiddleware = adaptMiddlewareToExpress(~basePath=config.basePath, middleware)

    app->useMiddleware((req, res, next) => {
      let _ =
        adaptedMiddleware(req, res, next)->Promise.catch(error => {
          let msg =
            error
            ->JsExn.fromException
            ->Option.flatMap(JsExn.message)
            ->Option.getOr("Unknown error")
          Console.error2("Frontman middleware error:", msg)
          setStatusCode(res, 500)
          endResponseWithData(res, "Internal Server Error")
          Promise.resolve()
        })
    })
  })

  // Inject annotation capture script into webpack build (dev only)
  api.chainWebpack(config => {
    let annotationCapturePath = resolve(__dirname, "../dist/annotation-capture.js")
    let entryPlugin = makeEntryPlugin(
      __dirname,
      annotationCapturePath,
      {"name": Null.null},
    )
    config->chainPlugin("frontman-annotation-capture")->chainUse(entryPlugin, [])
  })
}
