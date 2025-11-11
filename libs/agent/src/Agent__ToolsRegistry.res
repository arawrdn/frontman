// Tool registry - manages agent tools
type tool = module(Agent__Tool.T)

type t = array<tool>

let make = (): t => {
  [module(Agent__Tool__ListFiles), module(Agent__Tool__ReadFile), module(Agent__Tool__WriteFile)]
}
