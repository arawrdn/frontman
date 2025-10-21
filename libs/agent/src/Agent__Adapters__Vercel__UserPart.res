// Converters between Vercel UserPart and Domain message parts
//
// This module handles the translation between Vercel AI SDK's message format
// and our internal domain representation. The main challenge is handling
// Vercel's opaque imageData/fileData types which can be strings, Uint8Array,
// ArrayBuffer, or URL objects.

module Vercel = Agent__Bindings__Vercel
module DomainPart = Agent__Task__Message__Part
module DomainMessage = Agent__Task__Message

// ============================================================================
// Helpers
// ============================================================================

// Convert Vercel's opaque imageData/fileData to domain dataContent or URL string
// - URL object → extract href string (for Url variant)
// - Uint8Array → preserve as Uint8Array (for Data variant)
// - ArrayBuffer → preserve as ArrayBuffer (for Data variant)
// - string → check if URL or data string
type convertedData =
  | UrlResult(string) // URL string
  | DataResult(DomainPart.dataContent) // Data content

let convertVercelData = (data: 'a): convertedData => {
  if %raw(`data instanceof URL`) {
    UrlResult(%raw(`data.href`))
  } else if %raw(`data instanceof Uint8Array`) {
    DataResult(Uint8Array((Obj.magic(data): Uint8Array.t)))
  } else if %raw(`data instanceof ArrayBuffer`) {
    DataResult(ArrayBuffer((Obj.magic(data): ArrayBuffer.t)))
  } else if %raw(`data instanceof URL`) {
    UrlResult(Obj.magic(data)->WebAPI.URL.toJSON)
  } else {
    // Fallback: treat as string
    DataResult(String((Obj.magic(data): string)))
  }
}

// ============================================================================
// Converters
// ============================================================================

// Convert domain message part to Vercel UserPart (for sending to Vercel SDK)
let toVercel = (part: DomainMessage.User.contentParts): Vercel.UserPart.t => {
  switch part {
  | Text({content}) => Vercel.UserPart.text(content)

  | Image(Data({content, mediaType})) =>
    switch content {
    | String(str) => Vercel.UserPart.imageFromString(~url=str, ~mediaType)
    | Uint8Array(arr) => Vercel.UserPart.imageFromUint8Array(~data=arr, ~mediaType)
    | ArrayBuffer(buf) => Vercel.UserPart.imageFromArrayBuffer(~data=buf, ~mediaType)
    }

  | Image(Url({url, mediaType})) => Vercel.UserPart.imageFromString(~url, ~mediaType)

  | File({filename, mediaType, data: Data({content})}) =>
    switch content {
    | String(str) => Vercel.UserPart.fileFromString(~url=str, ~mediaType, ~filename)
    | Uint8Array(arr) => Vercel.UserPart.fileFromUint8Array(~data=arr, ~mediaType, ~filename)
    | ArrayBuffer(buf) => Vercel.UserPart.fileFromArrayBuffer(~data=buf, ~mediaType, ~filename)
    }

  | File({filename, mediaType, data: Url({url})}) =>
    Vercel.UserPart.fileFromString(~url, ~mediaType, ~filename)
  }
}

// Convert Vercel UserPart to domain message part (for receiving from Vercel SDK)
let fromVercel = (part: Vercel.UserPart.t): DomainMessage.User.contentParts => {
  switch part {
  | Text({text}) => Text({content: text})

  | Image(imagePart) =>
    switch convertVercelData(imagePart.image) {
    | UrlResult(url) => Image(Url({url, mediaType: imagePart.mediaType}))
    | DataResult(content) => Image(Data({content, mediaType: imagePart.mediaType}))
    }

  | File(filePart) =>
    switch convertVercelData(filePart.data) {
    | UrlResult(url) =>
      File({
        filename: filePart.filename,
        mediaType: filePart.mediaType,
        data: Url({url: url}),
      })
    | DataResult(content) =>
      File({
        filename: filePart.filename,
        mediaType: filePart.mediaType,
        data: Data({content: content}),
      })
    }
  }
}

let arrayToVercel = (parts: array<DomainMessage.User.contentParts>): array<Vercel.UserPart.t> => {
  Array.map(parts, toVercel)
}

let arrayFromVercel = (parts: array<Vercel.UserPart.t>): array<DomainMessage.User.contentParts> => {
  Array.map(parts, fromVercel)
}
