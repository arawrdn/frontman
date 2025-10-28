// Artifact - opaque type with safe construction
S.enableJson()
module Part = Agent__Task__Message__Part
@schema
type t = {
  artifactId: Agent__Id.t,
  name: @s.null option<string>,
  parts: array<Part.t>,
}

let make = (~name: option<string>=None, ~parts: array<Part.t>): t => {
  {
    artifactId: Agent__Id.make(),
    name,
    parts,
  }
}

// Accessor for getting parts
let getParts = (artifact: t): array<Part.t> => artifact.parts
let getId = (artifact: t): Agent__Id.t => artifact.artifactId
