// Main Agent module - exports all components

// Event schemas
module Events = Agent__Events

// Communication buses
module PluginBus = Agent__Bus__Plugin
module InternalBus = Agent__Bus__Internal

// Bindings
module Bindings = {
  module Fs = Agent__Bindings__Fs
  module Path = Agent__Bindings__Path
}

// Tools
module Tools = {
  module Filesystem = Agent__Tools__Filesystem
}
