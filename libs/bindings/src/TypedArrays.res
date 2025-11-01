// Uint8Array bindings for JavaScript typed arrays
// Uint8Array.t is a builtin type in ReScript

@get external length: Uint8Array.t => int = "length"
@send external slice: (Uint8Array.t, ~start: int, ~end: int) => Uint8Array.t = "slice"
@get_index external unsafeGet: (Uint8Array.t, int) => int = ""
@new external fromBuffer: ArrayBuffer.t => Uint8Array.t = "Uint8Array"
