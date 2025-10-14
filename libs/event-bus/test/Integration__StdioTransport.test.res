open Vitest

module Helpers = Integration__Helpers

// Test state - mutable ref to hold subprocess
let subprocess: ref<option<Bindings__ChildProcess.childProcess>> = ref(None)
module TestBus = EventBus.RemoteBus.Make(Fixtures__Events, EventBus.SubprocessTransport)
let testBus: ref<option<TestBus.t>> = ref(None)
describe("STDIO Transport Integration", () => {
  beforeEach(() => {
    let proc = Helpers.spawnFixture("Fixtures__EchoSubprocess")
    subprocess := Some(proc)

    // Create RemoteBus with SubprocessTransport
    testBus := Some(TestBus.make(proc))
  }) // Clean up subprocess after each test
  afterEach(() => {
    switch subprocess.contents {
    | Some(proc) => {
        let _ = Bindings__ChildProcess.kill(proc)
        subprocess := None
      }
    | None => ()
    }
  })

  describe("Basic Communication", () => {
    testAsync(
      "should send and receive messages through public API",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow
        // Collect response messages using RemoteBus.on()
        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        // Connect the test bus
        await TestBus.connect(testBus)

        // Send test message using public API
        await testBus->TestBus.emit(
          Fixtures__Events.Ping({
            message: "Hello from test!",
          }),
        )

        await Helpers.wait(200)

        // Assert on typed events, not JSON
        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThan(0)

        switch responses[0] {
        | Some(Fixtures__Events.Pong({message, originalMessage})) => {
            t->expect(message)->Expect.String.toContain("Echo:")
            t->expect(originalMessage)->Expect.toBe("Hello from test!")
          }
        | _ => t->expect(false)->Expect.toBe(true) // Fail test if wrong event type
        }
      },
      ~timeout=5000,
    )

    testAsync(
      "should preserve message data through serialization",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow

        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        await TestBus.connect(testBus)

        let testMessage = "Test message with special chars: !@#$%^&*()"
        await testBus->TestBus.emit(Fixtures__Events.Ping({message: testMessage}))

        await Helpers.wait(200)

        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThan(0)

        switch responses[0] {
        | Some(Fixtures__Events.Pong({originalMessage, _})) =>
          t->expect(originalMessage)->Expect.toBe(testMessage)
        | _ => t->expect(false)->Expect.toBe(true)
        }
      },
      ~timeout=5000,
    )
  })

  describe("Buffer Management", () => {
    testAsync(
      "should handle messages correctly (transport handles chunking)",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow

        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        await TestBus.connect(testBus)

        // Send message - transport handles any chunking automatically
        await testBus->TestBus.emit(
          Fixtures__Events.Ping({
            message: "Chunked message test",
          }),
        )

        await Helpers.wait(200)

        // Should receive 1 complete response
        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThanOrEqual(1)

        switch responses[0] {
        | Some(Fixtures__Events.Pong(_)) => () // Success - received pong
        | _ => t->expect(false)->Expect.toBe(true)
        }
      },
      ~timeout=5000,
    )

    testAsync(
      "should handle multiple messages sent quickly",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow

        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        await TestBus.connect(testBus)

        // Send 3 messages quickly
        await testBus->TestBus.emit(Fixtures__Events.Ping({message: "First"}))
        await testBus->TestBus.emit(Fixtures__Events.Ping({message: "Second"}))
        await testBus->TestBus.emit(Fixtures__Events.Ping({message: "Third"}))

        await Helpers.wait(300)

        // Should receive 3 responses
        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThanOrEqual(3)

        // Verify all responses are Pong events
        for i in 0 to 2 {
          switch responses[i] {
          | Some(Fixtures__Events.Pong(_)) => () // Success
          | _ => t->expect(false)->Expect.toBe(true)
          }
        }
      },
      ~timeout=5000,
    )
  })

  describe("Sequential Communication", () => {
    testAsync(
      "should handle multiple sequential messages",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow

        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        await TestBus.connect(testBus)

        // Send 5 messages in sequence
        for i in 0 to 4 {
          await testBus->TestBus.emit(
            Fixtures__Events.Ping({
              message: "Message " ++ Int.toString(i),
            }),
          )
          await Helpers.wait(50)
        }

        await Helpers.wait(300)

        // Should receive 5 responses
        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThanOrEqual(5)

        // Verify each response is a Pong event
        for i in 0 to 4 {
          switch responses[i] {
          | Some(Fixtures__Events.Pong({message, originalMessage})) => {
              t->expect(message)->Expect.String.toContain("Echo:")
              t->expect(originalMessage)->Expect.String.toContain("Message")
            }
          | _ => t->expect(false)->Expect.toBe(true)
          }
        }
      },
      ~timeout=5000,
    )

    testAsync(
      "should maintain message order",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow

        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        await TestBus.connect(testBus)

        // Send messages with identifiable content
        let testMessages = ["First", "Second", "Third"]
        for i in 0 to testMessages->Array.length - 1 {
          let msg = testMessages[i]->Option.getOrThrow
          await testBus->TestBus.emit(Fixtures__Events.Ping({message: msg}))
        }

        await Helpers.wait(300)

        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThanOrEqual(3)

        // Verify order is preserved
        let receivedMessages =
          responses
          ->Array.slice(~start=0, ~end=3)
          ->Array.map(
            event =>
              switch event {
              | Fixtures__Events.Pong({originalMessage, _}) => originalMessage
              | _ => ""
              },
          )

        t->expect(receivedMessages)->Expect.toEqual(["First", "Second", "Third"])
      },
      ~timeout=5000,
    )
  })

  describe("Public API Contract", () => {
    testAsync(
      "should emit and receive events through public API",
      async t => {
        let testBus = testBus.contents->Option.getOrThrow

        let responses = []
        let _unsubscribe = testBus->TestBus.on(
          event => {
            let _ = responses->Array.push(event)
          },
        )

        await TestBus.connect(testBus)

        await testBus->TestBus.emit(Fixtures__Events.Ping({message: "Envelope test"}))

        await Helpers.wait(200)

        t->expect(responses->Array.length)->Expect.Int.toBeGreaterThan(0)

        // Verify we received a properly typed Pong event
        switch responses[0] {
        | Some(Fixtures__Events.Pong({message, originalMessage})) => {
            t->expect(message)->Expect.String.toContain("Echo:")
            t->expect(originalMessage)->Expect.toBe("Envelope test")
          }
        | _ => t->expect(false)->Expect.toBe(true)
        }
      },
      ~timeout=5000,
    )
  })

  describe("Error Handling", () => {
    testAsync(
      "should reject connect if subprocess crashes before ready",
      async t => {
        let proc = Helpers.spawnFixture("Fixtures__CrashSubprocess")
        let crashBus = TestBus.make(proc)

        try {
          await TestBus.connect(crashBus)
          // Should not reach here
          t->expect(false)->Expect.toBe(true)
        } catch {
        | JsExn(error) => {
            // Should receive error about subprocess exiting
            let message = error->JsExn.message->Option.getOr("")
            t->expect(message)->Expect.String.toContain("exited before ready")
          }
        | _ => t->expect(false)->Expect.toBe(true)
        }

        // Cleanup
        let _ = Bindings__ChildProcess.kill(proc)
      },
      ~timeout=5000,
    )
  })
})
