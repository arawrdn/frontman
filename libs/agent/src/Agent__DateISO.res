// Date ISO string serialization/deserialization utilities

// Convert Date to ISO string
let fromDate: Date.t => string = date => date->Date.toISOString

// Convert ISO string to Date
let toDate: string => Date.t = isoString => Date.fromString(isoString)

// Schema for JSON serialization (Date <-> ISO string)
let schema: S.t<Date.t> = S.string->S.transform(_s => {
  parser: isoString => toDate(isoString),
  serializer: date => fromDate(date),
})
