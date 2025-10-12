// Functor that generates event module from schema
module Make = (
  Config: {
    type t
    let name: string
    let schema: S.t<t>
  },
) => {
  // Re-export config
  type t = Config.t
  let name = Config.name
  let schema = Config.schema

  // Generate toJson from schema
  let toJson = (event: t): Js.Json.t => {
    event->S.reverseConvertToJsonOrThrow(schema)
  }

  // Generate fromJson from schema
  let fromJson = (json: Js.Json.t): option<t> => {
    Some(json->S.parseOrThrow(schema))
  }

  // Type-safe constructor that validates
  let make = (data: t): result<t, string> => {
    try {
      // Round-trip through schema for validation
      let json = data->S.reverseConvertToJsonOrThrow(schema)
      let validated = json->S.parseOrThrow(schema)
      Ok(validated)
    } catch {
    | exn =>
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error("Validation failed: " ++ message)
    }
  }
}
