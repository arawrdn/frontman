// Simple test for Agent__Task__Message serialization
S.enableJson()

open Vitest

describe("Agent__Task__Message simple serialization test", () => {
  test("should serialize System message to JSON string", _ctx => {
    let msg = Agent__Task__Message.System({
      id: Agent__Id.fromString("test-id")->Option.getOrThrow,
      taskId: None,
      content: "System message content",
    })

    Console.log2("Created message:", msg)

    // First convert to JSON value
    let jsonValue = msg->S.reverseConvertOrThrow(Agent__Task__Message.schema)
    Console.log2("Converted to JSON value:", jsonValue)

    // Then stringify (cast unknown to JSON.t)
    let jsonString = JSON.stringify(jsonValue->Obj.magic)
    Console.log2("Serialized to JSON string:", jsonString)

    // Verify it's valid JSON
    let parsed = JSON.parseOrThrow(jsonString)
    Console.log2("Parsed back:", parsed)
  })

  test("should serialize and deserialize User message with Image containing binary data", ctx => {
    // Create a Uint8Array with some test data
    let binaryData = Uint8Array.fromArray([72, 101, 108, 108, 111]) // "Hello" in bytes

    let msg: Agent__Task__Message.t = User({
      taskId: None,
      content: List([
        Image(
          Data({
            content: Uint8Array(binaryData),
            mediaType: Some("image/png"),
          }),
        ),
      ]),
    })

    Console.log2("Created message with binary data:", msg)

    // Serialize to JSON
    let jsonValue = msg->S.reverseConvertOrThrow(Agent__Task__Message.schema)
    let jsonString = JSON.stringify(jsonValue->Obj.magic)
    Console.log2("Serialized to JSON string:", jsonString)

    // Verify the JSON contains base64 encoding
    ctx->expect(jsonString->String.includes("base64"))->Expect.toBe(true)

    // Deserialize back
    let parsed = JSON.parseOrThrow(jsonString)
    let deserialized = parsed->S.parseOrThrow(Agent__Task__Message.schema)
    Console.log2("Deserialized message:", deserialized)

    // Verify the binary data round-tripped correctly
    switch deserialized {
    | User({content: List([Image(Data({content, _}))])}) =>
      switch content {
      | Uint8Array(arr) => {
          Console.log2("Recovered Uint8Array:", arr)
          // Verify the data matches
          ctx->expect(arr)->Expect.toEqual(binaryData)
        }
      | _ => ctx->expect(true)->Expect.toBe(false) // Fail if not Uint8Array
      }
    | _ => ctx->expect(true)->Expect.toBe(false) // Fail if wrong structure
    }
  })
})
