@schema
type t = @as("id") Id(string)

let make = (): t => {
  let uuid = %raw(`crypto.randomUUID()`)
  Id(uuid)
}

let fromString = (str: string): option<t> => {
  if str != "" {
    Some(Id(str))
  } else {
    None
  }
}

// Only expose toString when needed for serialization
let toString = (Id(str): t): string => str
