// Re-export store and dispatch
let store = Client__State__Store.store
let dispatch = Client__State__Store.dispatch

// Re-export types
type state = Client__State__StateReducer.state
type action = Client__State__StateReducer.action

// Hook for selecting state
let useSelector = selection =>
  AskTheLlmReactStatestore.StateStore.useSelector(store, selection)

// Re-export selectors
module Selectors = Client__State__StateReducer.Selectors

// Action creators
module Actions = {
  let setUrl = (url: string) => dispatch(SetUrl(url))
  let addMessage = (message: string) => dispatch(AddMessage(message))
}
