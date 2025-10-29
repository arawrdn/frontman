let name = "AskTheLlm::StateReducer"

open AskTheLlm__Types

let defaultState: state = {
    url: "danni",
    messages: [],
}

type state = state
type action = action

let actionToString = action => {
  switch action {
  | SetUrl(url) => "SetUrl(" + url + ")"
  | AddMessage(message) => "AddMessage(" + message + ")"
  }
}

type effect =
  | SendMessage(string)

let handleEffect = (effect, _state, _dispatch) => {
  switch effect {
  | SendMessage(_message) => ()
  }
}

let next = (state, action) => {
  switch action {
  | SetUrl(url) => AskTheLlmReactStatestore.StateReducer.update({...state, url})
  | AddMessage(message) => AskTheLlmReactStatestore.StateReducer.update({...state, messages: state.messages->Array.concat([message])})
  }
}

module Selectors = {
    let url = (state: state) => state.url
    let messages = (state: state) => state.messages
}
