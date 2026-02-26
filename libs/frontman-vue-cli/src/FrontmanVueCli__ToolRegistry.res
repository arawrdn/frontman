// Tool registry for Vue CLI - composes core tools with Vue CLI-specific tools

module Core = FrontmanFrontmanCore
module CoreRegistry = Core.FrontmanCore__ToolRegistry

// Re-export types from core
type tool = CoreRegistry.tool
type t = CoreRegistry.t

// Vue CLI specific tools
let vuecliTools: array<tool> = [module(FrontmanVueCli__Tool__GetLogs)]

let make = (): t => {
  CoreRegistry.coreTools()
  ->CoreRegistry.addTools(vuecliTools)
  ->CoreRegistry.replaceByName(module(FrontmanVueCli__Tool__EditFile))
}

// Re-export functions from core
let getToolByName = CoreRegistry.getToolByName
let getToolDefinitions = CoreRegistry.getToolDefinitions
let addTools = CoreRegistry.addTools
let count = CoreRegistry.count
