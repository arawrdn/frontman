// Part types - opaque construction for type safety

// ============ TextPart ============

module TextPart: {
  type t
  let make: (~text: string, ~metadata: option<Dict.t<JSON.t>>=?) => t
  let getText: t => string
  let getMetadata: t => option<Dict.t<JSON.t>>
} = {
  type t = {
    text: string,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~text, ~metadata=None) => {
    {text, metadata}
  }

  let getText = (part: t): string => part.text
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ FilePart ============

module File: {
  type t
  let make: (~name: option<string>=?, ~mimeType: string, ~bytes: string) => t
  let getName: t => option<string>
  let getMimeType: t => string
  let getBytes: t => string
} = {
  type t = {
    name: option<string>,
    mimeType: string,
    bytes: string, // base64 encoded
  }

  let make = (~name=None, ~mimeType, ~bytes) => {
    {name, mimeType, bytes}
  }

  let getName = (file: t): option<string> => file.name
  let getMimeType = (file: t): string => file.mimeType
  let getBytes = (file: t): string => file.bytes
}

module FilePart: {
  type t
  let make: (~file: File.t, ~metadata: option<Dict.t<JSON.t>>=?) => t
  let getFile: t => File.t
  let getMetadata: t => option<Dict.t<JSON.t>>
} = {
  type t = {
    file: File.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~file, ~metadata=None) => {
    {file, metadata}
  }

  let getFile = (part: t): File.t => part.file
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ DataPart ============

module DataPart: {
  type t
  let make: (~data: JSON.t, ~metadata: option<Dict.t<JSON.t>>=?) => t
  let getData: t => JSON.t
  let getMetadata: t => option<Dict.t<JSON.t>>
} = {
  type t = {
    data: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }

  let make = (~data, ~metadata=None) => {
    {data, metadata}
  }

  let getData = (part: t): JSON.t => part.data
  let getMetadata = (part: t): option<Dict.t<JSON.t>> => part.metadata
}

// ============ Part Union ============

type t =
  | Text(TextPart.t)
  | File(FilePart.t)
  | Data(DataPart.t)

// Convenience constructors
let text = (~text, ~metadata=None) => Text(TextPart.make(~text, ~metadata))
let file = (~file, ~metadata=None) => File(FilePart.make(~file, ~metadata))
let data = (~data, ~metadata=None) => Data(DataPart.make(~data, ~metadata))
