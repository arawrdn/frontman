// Middleware factory for Vue CLI
// Thin wrapper around shared core middleware

module Core = FrontmanFrontmanCore
module CoreMiddleware = Core.FrontmanCore__Middleware
module CoreMiddlewareConfig = Core.FrontmanCore__MiddlewareConfig
module Config = FrontmanVueCli__Config
module ToolRegistry = FrontmanVueCli__ToolRegistry

type config = Config.t

// Convert Vue CLI config to core middleware config
let toMiddlewareConfig = (config: Config.t): CoreMiddlewareConfig.t => {
  projectRoot: config.projectRoot,
  sourceRoot: config.sourceRoot,
  basePath: config.basePath,
  serverName: config.serverName,
  serverVersion: config.serverVersion,
  clientUrl: config.clientUrl,
  clientCssUrl: config.clientCssUrl,
  entrypointUrl: config.entrypointUrl,
  isLightTheme: config.isLightTheme,
  frameworkLabel: "Vue CLI",
}

// Create middleware from a config
// Returns request => promise<option<response>>
// None means "not handled, pass through to next middleware"
let createMiddleware = (config: Config.t) => {
  let registry = ToolRegistry.make()
  let middlewareConfig = toMiddlewareConfig(config)
  CoreMiddleware.createMiddleware(~config=middlewareConfig, ~registry)
}
