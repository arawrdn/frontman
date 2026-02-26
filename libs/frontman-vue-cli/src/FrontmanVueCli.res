// Frontman Vue CLI Integration - exposes framework tools via HTTP
// Used by FrontmanClient__Relay to execute file system operations

module Config = FrontmanVueCli__Config
module Middleware = FrontmanVueCli__Middleware
module Server = FrontmanVueCli__Server
module ToolRegistry = FrontmanVueCli__ToolRegistry
module ServicePlugin = FrontmanVueCli__ServicePlugin

// Re-export core SSE for convenience
module SSE = FrontmanFrontmanCore.FrontmanCore__SSE

// Re-export for convenience
let createMiddleware = Middleware.createMiddleware
let makeConfig = Config.makeFromObject
type config = Config.t
type configInput = Config.jsConfigInput

// Service plugin export — main entry point for Vue CLI
let servicePlugin = ServicePlugin.servicePlugin
