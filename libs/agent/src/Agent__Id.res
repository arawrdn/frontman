@schema
type t = string

let make = (): t => {
  let uuid = %raw(`crypto.randomUUID()`)
  uuid
}

let fromString = (str: string): option<t> => {
  if str != "" {
    Some(str)
  } else {
    None
  }
}

// Only expose toString when needed for serialization
let toString = (str: t): string => str
