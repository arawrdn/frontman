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

    // Verify TaskCreated event was emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(1)

    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskCreated(_)) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }
  })

  test("TaskStateChanged event is emitted when StartProcessing command succeeds", t => {
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

    // Verify TaskStateChanged event was emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(1)

    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskStateChanged(_)) => () // Success
    | _ => t->expect(false)->Expect.toBe(true) // Fail the test
    }
  })

  test("TaskMessageAdded event is emitted when AddMessage command succeeds", t => {
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

    // Verify TaskMessageAdded event was emitted
    t->expect(receivedEvents.contents->Array.length)->Expect.toBe(1)

    switch receivedEvents.contents->Array.at(0) {
    | Some(TaskMessageAdded({task: _, message: _})) => () // Success
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

    // Should have TaskMessageAdded and TaskStateChanged
    let hasMessageAdded = receivedEvents.contents->Array.some(event => {
      switch event {
      | TaskMessageAdded(_) => true
      | _ => false
      }
    })
    let hasStateChanged = receivedEvents.contents->Array.some(event => {
      switch event {
      | TaskStateChanged(_) => true
      | _ => false
      }
    })

    t->expect(hasMessageAdded)->Expect.toBe(true)
    t->expect(hasStateChanged)->Expect.toBe(true)
  })
})
