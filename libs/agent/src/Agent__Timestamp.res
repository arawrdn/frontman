type t = Timestamp(string)

let make = () => {
  let iso = %raw(`new Date().toISOString()`)
  Timestamp(iso)
}

let toString = (Timestamp(str): t): string => str
