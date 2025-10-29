let store = StateStore.make(module(AskTheLlm__StateReducer), AskTheLlm__StateReducer.defaultState)

let dispatch = action => {
  store->StateStore.dispatch(action)
}
