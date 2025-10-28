// Base64 encoding/decoding utilities for Uint8Array

// Convert Uint8Array to base64 string
let fromUint8Array: Uint8Array.t => string = %raw(`
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

// Convert base64 string to Uint8Array
let toUint8Array: string => Uint8Array.t = %raw(`
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

// Schema for JSON serialization (Uint8Array <-> base64 string)
let schema: S.t<Uint8Array.t> = S.string->S.transform(_s => {
  parser: base64 => toUint8Array(base64),
  serializer: uint8Array => fromUint8Array(uint8Array),
})

// Get buffer from Uint8Array
@get external getBuffer: Uint8Array.t => ArrayBuffer.t = "buffer"

// Schema for ArrayBuffer (converts to Uint8Array first, then base64)
let arrayBufferSchema: S.t<ArrayBuffer.t> = S.string->S.transform(_s => {
  parser: base64 => {
    let uint8 = toUint8Array(base64)
    getBuffer(uint8)
  },
  serializer: arrayBuffer => {
    let uint8 = Uint8Array.fromBuffer(arrayBuffer)
    fromUint8Array(uint8)
  },
})
