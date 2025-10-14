// Test helper functions for integration tests
// Mirrors the helpers from stdio-transport.test.ts

// Helper to spawn a compiled ReScript fixture
let spawnFixture = (fixtureName: string): Bindings__ChildProcess.childProcess => {
  let fixturePath = Bindings__Path.join([Bindings__Process.__dirname, "../test", fixtureName ++ ".res.mjs"])
  EventBus.Subprocess.spawn(fixturePath)
}

// Helper to wait for a given number of milliseconds
let wait = async (ms: int): unit => {
  await Js.Promise2.make((~resolve, ~reject as _) => {
    let _ = Bindings__Process.setTimeout(() => resolve(), ms)
  })
}
