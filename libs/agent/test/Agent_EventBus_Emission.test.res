// Test that EventBus events are emitted when task commands are executed

open Vitest

describe("EventBus emission", () => {
  test("TaskCreated event is emitted when Create command succeeds", t => {
    let agent = Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])

    // Subscribe to events
    let _unsubscribe = agent.eventBus->Agent.EventBus.on(event => {
      receivedEvents := Array.concat(receivedEvents.contents, [event])
    })

    // Create a task
    let message = Agent.TaskMessage.User({
      taskId: None,
      content: String("test message"),
    })
    let result = agent->Agent.sendMessage(message)

    // Verify task was created
    switch result {
    | Ok(_) => () // Success
    | Error(err) => t->expect(err)->Expect.toBe("Expected Ok, got Error")
    }

    // Verify Created domain event was emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(1)

    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskEvent(_, Created(_))) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }
  })

  test("ProcessingStarted event is emitted when StartProcessing command succeeds", t => {
    let agent = Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])

    // Create a task first
    let message = Agent.TaskMessage.User({
      taskId: None,
      content: String("test message"),
    })
    let taskResult = agent->Agent.sendMessage(message)

    let task = switch taskResult {
    | Ok(t) => t
    | Error(_) => JsError.throwWithMessage("Failed to create task")
    }

    // Clear events from creation
    receivedEvents := []

    // Subscribe to events
    let _unsubscribe = agent.eventBus->Agent.EventBus.on(event => {
      receivedEvents := Array.concat(receivedEvents.contents, [event])
    })

    // Start processing
    let result = Agent.executeTaskCommand(
      agent,
      task.id,
      Agent.TaskCommands.StartProcessing({message: None}),
    )

    // Verify command succeeded
    switch result {
    | Ok(_) => () // Success
    | Error(err) => t->expect(err)->Expect.toBe("Expected Ok, got Error")
    }

    // Verify ProcessingStarted event was emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(1)

    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskEvent(_, ProcessingStarted(_))) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }
  })

  test("MessageAdded event is emitted when AddMessage command succeeds", t => {
    let agent = Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])

    // Create a task first
    let initialMessage = Agent.TaskMessage.User({
      taskId: None,
      content: String("initial message"),
    })
    let taskResult = agent->Agent.sendMessage(initialMessage)

    let task = switch taskResult {
    | Ok(t) => t
    | Error(_) => JsError.throwWithMessage("Failed to create task")
    }

    // Clear events from creation
    receivedEvents := []

    // Subscribe to events
    let _unsubscribe = agent.eventBus->Agent.EventBus.on(event => {
      receivedEvents := Array.concat(receivedEvents.contents, [event])
    })

    // Add a message
    let newMessage = Agent.TaskMessage.User({
      taskId: Some(task.id),
      content: String("new message"),
    })
    let result = Agent.executeTaskCommand(
      agent,
      task.id,
      Agent.TaskCommands.AddMessage({message: newMessage}),
    )

    // Verify command succeeded
    switch result {
    | Ok(_) => () // Success
    | Error(err) => t->expect(err)->Expect.toBe("Expected Ok, got Error")
    }

    // Verify MessageAdded event was emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(1)

    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskEvent(_, MessageAdded({message: _}))) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }
  })

  test("Multiple events emitted when AddMessage on InputRequired task", t => {
    let agent = Agent.make({projectRoot: ".", apiKey: "test-api-key"})
    let receivedEvents: ref<array<Agent.EventBus.events>> = ref([])

    // Create a task and put it in InputRequired status
    let initialMessage = Agent.TaskMessage.User({
      taskId: None,
      content: String("initial message"),
    })
    let taskResult = agent->Agent.sendMessage(initialMessage)

    let task = switch taskResult {
    | Ok(t) => t
    | Error(_) => JsError.throwWithMessage("Failed to create task")
    }

    // Start processing first (task needs to be Working to request input)
    let _ = Agent.executeTaskCommand(
      agent,
      task.id,
      Agent.TaskCommands.StartProcessing({message: None}),
    )

    // Request input
    let question = Agent.TaskMessage.User({
      taskId: Some(task.id),
      content: String("What should I do?"),
    })
    let _ = Agent.executeTaskCommand(
      agent,
      task.id,
      Agent.TaskCommands.RequestInput({question: question}),
    )

    // Clear events
    receivedEvents := []

    // Subscribe to events
    let _unsubscribe = agent.eventBus->Agent.EventBus.on(event => {
      receivedEvents := Array.concat(receivedEvents.contents, [event])
    })

    // Add a message (should emit both MessageAdded and Resumed events)
    let response = Agent.TaskMessage.User({
      taskId: Some(task.id),
      content: String("Do this"),
    })
    let _ = Agent.executeTaskCommand(
      agent,
      task.id,
      Agent.TaskCommands.AddMessage({message: response}),
    )

    // Verify both events were emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(2)

    // Should have MessageAdded and Resumed domain events
    let hasMessageAdded = receivedEvents.contents->Array.some(event => {
      switch event {
      | TaskEvent(_, MessageAdded(_)) => true
      | _ => false
      }
    })
    let hasResumed = receivedEvents.contents->Array.some(event => {
      switch event {
      | TaskEvent(_, Resumed(_)) => true
      | _ => false
      }
    })

    t->expect(hasMessageAdded)->Expect.toBe(true)
    t->expect(hasResumed)->Expect.toBe(true)
  })
})
