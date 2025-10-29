# React StateStore

ReScript state management for React with pure reducers and side effects.

Two tools that work well together (but you can use just one):

- **StateStore**: Global state across your app (like Redux)
- **StateReducer**: Local state for a single component (like useReducer)

Pick what you need - global, local, or both.

## Example: Global State with StateStore

```rescript
// 1. Define types (Counter__Types.res)
type state = {count: int}
type action = Increment | Decrement | Reset
type effect = LogCount(int)

// 2. Implement reducer (Counter__Reducer.res)
let name = "Counter"
type state = state
type action = action
type effect = effect

let next = (state, action) => {
  switch action {
  | Increment => StateReducer.update(
      {count: state.count + 1},
      ~sideEffect=LogCount(state.count + 1)
    )
  | Decrement => StateReducer.update({count: state.count - 1})
  | Reset => StateReducer.update({count: 0})
  }
}

let handleEffect = (effect, _state, _dispatch) => {
  switch effect {
  | LogCount(n) => Console.log(`Count is now: ${n->Int.toString}`)
  }
}

// 3. Create store (Counter__Store.res)
let store = StateStore.make(module(Counter__Reducer), {count: 0})

let dispatch = action => store->StateStore.dispatch(action)

module Selectors = {
  let count = (state: state) => state.count
}

// 4. Use in component (App.res)
@react.component
let make = () => {
  let count = StateStore.useSelector(Counter__Store.store, Counter__Store.Selectors.count)

  <div>
    <p>{React.string(`Count: ${count->Int.toString}`)}</p>
    <button onClick={_ => Counter__Store.dispatch(Increment)}>
      {React.string("+")}
    </button>
    <button onClick={_ => Counter__Store.dispatch(Decrement)}>
      {React.string("-")}
    </button>
    <button onClick={_ => Counter__Store.dispatch(Reset)}>
      {React.string("Reset")}
    </button>
  </div>
}
```

## What you get

- **Pure reducers**: `next` function computes new state without side effects
- **Separate effects**: `handleEffect` runs side effects after state updates
- **Efficient selectors**: Components only re-render when their selected data changes
- **Type safety**: ReScript ensures type correctness across your state management

## Key concepts

**StateReducer**: For local component state
```rescript
let (state, dispatch) = StateReducer.useReducer(module(MyReducer), initialState)
```

**StateStore**: For global state with selectors
```rescript
let value = StateStore.useSelector(store, state => state.someField)
```
