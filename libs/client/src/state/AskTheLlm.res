let store = AskTheLlm__Store.store
let dispatch = AskTheLlm__Store.dispatch

let useSelector = selection =>
  AskTheLlmReactStatestore.StateStore.useSelector(store, selection)

// let emptyLiveDemo = LiveDemo__StateReducer.emptyLiveDemo

module Selectors = AskTheLlm__StateReducer.Selectors
module Actions = {
    let setUrl = (url: string) => dispatch(SetUrl(url))
    let addMessage = (message: string) => dispatch(AddMessage(message))
}
