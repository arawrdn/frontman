// Test helper functions for integration tests
// Mirrors the helpers from stdio-transport.test.ts

module Bindings = AskTheLlmBindings
// Helper to spawn a compiled ReScript fixture

let spawnFixture = (fixtureName: string): Bindings.ChildProcess.childProcess => {
  module Bindings = AskTheLlmBindings
  let fixturePath = Bindings.Path.join([
    Bindings.Process.__dirname,
    "../test",
    fixtureName ++ ".res.mjs",
  ])
  EventBus.Subprocess.spawn(fixturePath)
}

// Helper to wait for a given number of milliseconds
let wait = async (ms: int): unit => {
  await Js.Promise2.make((~resolve, ~reject as _) => {
    let _ = Bindings.Process.setTimeout(() => resolve(), ms)
  })
}
