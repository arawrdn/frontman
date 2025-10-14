open Vitest

// Test: Basic agent spawn and file read
describe("Agent Core Integration", () => {
  // Track test context for cleanup
  let testContext: ref<option<TestHelpers.testContext>> = ref(None)
  let fixtureDir = TestHelpers.getFixturePath(TestHelpers.defaultFixture)
  beforeEachAsync(async () => {
    let ctx = await TestHelpers.setupAgentTest()
    testContext := Some(ctx)
  })
  afterEachAsync(async () => {
    // Clean up test context properly
    switch testContext.contents {
    | Some(ctx) => {
        TestHelpers.cleanupAgentTest(ctx)
        testContext := None
      }
    | None => ()
    }
  })

  describe("Agent Lifecycle", () => {
    testAsync(
      "should spawn and connect successfully",
      async t => {
        // If we got here, connection succeeded
        t->expect(true)->Expect.toBe(true)
      },
      ~timeout=TestHelpers.connectionTimeout,
    )
  })

  describe("File Operations", () => {
    testAsync(
      "should read file and respond with content summary",
      async t => {
        let ctx = testContext.contents->Option.getOrThrow
        let request = TestEventHelpers.makeTestUserRequest(
          ~requestId="test-read-file",
          ~userMessage="Read the Button.tsx file and tell me what it does",
          ~fixtureDir,
          (),
        )

        await ctx.bus->TestHelpers.AgentBus.emit(Agent.PluginBus.UserRequest(request))
        await TestEventHelpers.waitForCompletion(
          ~events=ctx.responses,
          ~timeout=TestHelpers.llmTimeout,
          (),
        )

        let responseEvent = ctx.responses.contents->Array.find(TestEventHelpers.isAgentResponse)

        switch responseEvent {
        | None => TestEventHelpers.failTest("Expected agent response but got none")
        | Some(event) =>
          switch TestEventHelpers.getResponseMessage(event) {
          | None => TestEventHelpers.failTest("Response event has no message")
          | Some(msg) => {
              let lowerMsg = msg->String.toLowerCase
              t->expect(lowerMsg)->Expect.String.toContain("button")
            }
          }
        }
      },
      ~timeout=TestHelpers.fullTestTimeout,
    )
  })

  describe("Error Handling", () => {
    testAsync(
      "should handle requests for non-existent files gracefully",
      async t => {
        let ctx = testContext.contents->Option.getOrThrow

        let request = TestEventHelpers.makeTestUserRequest(
          ~requestId="test-invalid-file",
          ~userMessage="Read the NonExistent.tsx file",
          ~fixtureDir,
          (),
        )

        await ctx.bus->TestHelpers.AgentBus.emit(Agent.PluginBus.UserRequest(request))
        await TestEventHelpers.waitForCompletion(
          ~events=ctx.responses,
          ~timeout=TestHelpers.llmTimeout,
          (),
        )

        // LLM should handle this gracefully with a response (not crash)
        let responseEvent = ctx.responses.contents->Array.find(TestEventHelpers.isAgentResponse)

        switch responseEvent {
        | None => TestEventHelpers.failTest("Expected graceful response for non-existent file")
        | Some(event) =>
          switch TestEventHelpers.getResponseMessage(event) {
          | None => TestEventHelpers.failTest("Response has no message")
          | Some(msg) => {
              let lowerMsg = msg->String.toLowerCase
              // Should mention it doesn't exist or can't find it
              let mentionsIssue =
                lowerMsg->String.includes("not found") ||
                lowerMsg->String.includes("doesn't exist") ||
                lowerMsg->String.includes("cannot find") ||
                lowerMsg->String.includes("can't find")

              if !mentionsIssue {
                TestEventHelpers.failTest("Response should indicate file doesn't exist")
              }
              t->expect(mentionsIssue)->Expect.toBe(true)
            }
          }
        }
      },
      ~timeout=TestHelpers.fullTestTimeout,
    )
  })

  describe("Status Updates", () => {
    testAsync(
      "should send status updates during processing",
      async t => {
        let ctx = testContext.contents->Option.getOrThrow

        let request = TestEventHelpers.makeTestUserRequest(
          ~requestId="test-status-updates",
          ~userMessage="List all files in this project",
          ~fixtureDir,
          (),
        )

        await ctx.bus->TestHelpers.AgentBus.emit(Agent.PluginBus.UserRequest(request))
        await TestEventHelpers.waitForCompletion(
          ~events=ctx.responses,
          ~timeout=TestHelpers.llmTimeout,
          (),
        )

        let statusUpdates = ctx.responses.contents->Array.filter(TestEventHelpers.isStatusUpdate)

        // Should have at least one status update
        if statusUpdates->Array.length == 0 {
          TestEventHelpers.failTest("Expected at least one status update")
        }

        // Status updates should have non-empty messages
        let hasValidMessage = statusUpdates->Array.some(
          event => {
            switch TestEventHelpers.getStatusMessage(event) {
            | Some(msg) => msg->String.length > 0
            | None => false
            }
          },
        )

        if !hasValidMessage {
          TestEventHelpers.failTest("Status updates should contain non-empty messages")
        }

        t->expect(hasValidMessage)->Expect.toBe(true)
      },
      ~timeout=TestHelpers.fullTestTimeout,
    )
  })
})
