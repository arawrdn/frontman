module Core = Middleware__Core

// Vite middleware configuration type
// This can be the same as Nextjs__Config.t or a separate type
// For now, we'll reuse Nextjs__Config.t to share the config structure
type config = Nextjs__Config.t

// Convert Nextjs__Config.t to Core.config
let configToCore = (config: config): Core.config => {
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

// Create a Vite middleware function
// Returns a standard Web API middleware that returns None for pass-through, Some(response) if handled
// This can be used directly with Vite's server without needing Next.js dependencies
let createMiddleware = (conf: config) => {
  let coreConfig = configToCore(conf)
  Core.createMiddleware(coreConfig)
}

