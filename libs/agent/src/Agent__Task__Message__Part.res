// Part types - opaque construction for type safety

// Enable JSON support in Sury
S.enableJson()

// ============ TextPart ============

module TextPart = {
  @schema
  type t = {content: string}
}

// ============ Shared Data Content Types ============

// Data content - can be string (base64, etc) or binary data
type dataContent =
  | String(string)
  | Uint8Array(Uint8Array.t)
  | ArrayBuffer(ArrayBuffer.t)

// Base64 encoding/decoding helpers
let base64Encode: Uint8Array.t => string = %raw(`
  (uint8Array) => {
    if (typeof Buffer !== 'undefined') {
      // Node.js environment
      return Buffer.from(uint8Array).toString('base64');
    } else {
      // Browser environment
      const binary = String.fromCharCode.apply(null, Array.from(uint8Array));
      return btoa(binary);
    }
  }
`)

let base64Decode: string => Uint8Array.t = %raw(`
  (base64) => {
    if (typeof Buffer !== 'undefined') {
      // Node.js environment
      return new Uint8Array(Buffer.from(base64, 'base64'));
    } else {
      // Browser environment
      const binary = atob(base64);
      const bytes = new Uint8Array(binary.length);
      for (let i = 0; i < binary.length; i++) {
        bytes[i] = binary.charCodeAt(i);
      }
      return bytes;
    }
  }
`)

// Type for JSON representation of dataContent
type dataContentJson = {\"type": string, value: string}

// Custom schema for dataContent with base64 transformation
// This schema automatically converts binary data to/from base64 for JSON serialization
let dataContentSchema: S.t<dataContent> = S.object(s => {
  \"type": s.field("type", S.string),
  value: s.field("value", S.string),
})->S.transform(s => {
  // Parser: JSON -> dataContent (convert base64 to binary if needed)
  parser: json => {
    switch json.\"type" {
    | "string" => String(json.value)
    | "base64" => Uint8Array(base64Decode(json.value))
    | invalidType => s.fail(`Invalid dataContent type: ${invalidType}`)
    }
  },
  // Serializer: dataContent -> JSON (convert binary to base64)
  serializer: dataContent => {
    switch dataContent {
    | String(str) => {\"type": "string", value: str}
    | Uint8Array(arr) => {\"type": "base64", value: base64Encode(arr)}
    | ArrayBuffer(buf) => {
        let uint8 = Uint8Array.fromBuffer(buf)
        {\"type": "base64", value: base64Encode(uint8)}
      }
    }
  },
})

// ============ FilePart ============
module FilePart = {
  @schema
  type data =
    | Data({content: @s.matches(dataContentSchema) dataContent})
    | Url({url: string})

  @schema
  type t = {
    filename: option<string>,
    mediaType: string,
    data: data,
  }
}

module ImagePart = {
  @schema
  type t =
    | Data({content: @s.matches(dataContentSchema) dataContent, mediaType: option<string>})
    | Url({url: string, mediaType: option<string>})
}

// ============ DataPart ============

module DataPart = {
  @schema
  type t = {
    data: JSON.t,
    metadata: option<Dict.t<JSON.t>>,
  }
}

// ============ ToolUsePart ============

module ToolCallPart = {
  @schema
  type t = {
    toolCallId: string,
    toolName: string,
    args: JSON.t,
  }
}

// ============ ToolResultPart ============

module ToolResultPart = {
  module Content = {
    @schema
    type t = Text(string) | Media({data: string, mediaType: string})
  }

  module Output = {
    @schema
    type t =
      | Text(string)
      | JSON(JSON.t)
      | ErrorText(string)
      | ErrorJSON(JSON.t)
      | Content(array<Content.t>)
  }

  @schema
  type t = {
    toolCallId: string,
    toolName: string,
    output: Output.t,
    providerOptions: option<JSON.t>,
  }
}

// ============ Part Union ============

// Now has @schema - binary data is handled via base64 transformation
@schema
type t =
  | Text(TextPart.t)
  | File(FilePart.t)
  | Data(DataPart.t)
  | ToolCall(ToolCallPart.t)
  | ToolResult(ToolResultPart.t)
