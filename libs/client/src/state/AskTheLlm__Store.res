let store = AskTheLlmReactStatestore.StateStore.make(module(AskTheLlm__StateReducer), AskTheLlm__StateReducer.defaultState)

let dispatch = action => {
  store->AskTheLlmReactStatestore.StateStore.dispatch(action)
}
