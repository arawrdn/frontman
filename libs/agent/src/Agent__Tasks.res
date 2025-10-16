// Task registry - manages collection of tasks
type t = ref<Dict.t<Agent__Task.t>>

let make = (): t => ref(Dict.make())

let add = (registry: t, task: Agent__Task.t): unit => {
  Dict.set(registry.contents, Agent__Task__Id.toString(task.id), task)
}

let update = (registry: t, task: Agent__Task.t): unit => {
  Dict.set(registry.contents, Agent__Task__Id.toString(task.id), task)
}

let get = (registry: t, id: Agent__Task__Id.t): option<Agent__Task.t> => {
  Dict.get(registry.contents, Agent__Task__Id.toString(id))
}

let getAll = (registry: t): array<Agent__Task.t> => {
  registry.contents->Dict.valuesToArray
}

let remove = (registry: t, id: Agent__Task__Id.t): unit => {
  Dict.delete(registry.contents, Agent__Task__Id.toString(id))
}
