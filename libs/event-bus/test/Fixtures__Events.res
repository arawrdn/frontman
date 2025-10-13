type t =
  | Ping({message: string})
  | Pong({message: string, originalMessage: string})

let eventName = event =>
  switch event {
  | Ping(_) => "test.ping"
  | Pong(_) => "test.pong"
  }

let toJson = event =>
  switch event {
  | Ping({message}) => {
      let obj = Js.Dict.empty()
      Js.Dict.set(obj, "message", message->Js.Json.string)
      obj->Js.Json.object_
    }
  | Pong({message, originalMessage}) => {
      let obj = Js.Dict.empty()
      Js.Dict.set(obj, "message", message->Js.Json.string)
      Js.Dict.set(obj, "originalMessage", originalMessage->Js.Json.string)
      obj->Js.Json.object_
    }
  }

let fromJson = (name, json) => {
  switch name {
  | "test.ping" => {
      let message =
        json
        ->Js.Json.decodeObject
        ->Belt.Option.flatMap(obj => Js.Dict.get(obj, "message"))
        ->Belt.Option.flatMap(Js.Json.decodeString)
        ->Belt.Option.getExn
      Some(Ping({message: message}))
    }
  | "test.pong" => {
      let obj = json->Js.Json.decodeObject->Belt.Option.getExn
      let message =
        Js.Dict.get(obj, "message")
        ->Belt.Option.flatMap(Js.Json.decodeString)
        ->Belt.Option.getExn
      let originalMessage =
        Js.Dict.get(obj, "originalMessage")
        ->Belt.Option.flatMap(Js.Json.decodeString)
        ->Belt.Option.getExn
      Some(Pong({message, originalMessage}))
    }
  | _ => None
  }
}
