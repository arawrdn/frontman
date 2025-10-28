// Artifact - opaque type with safe construction
module Part = Agent__Task__Message__Part
@schema
type t = {
  artifactId: Agent__Id.t,
  name: @s.null option<string>,
  parts: array<Part.t>,
  metadata: @s.null option<Dict.t<JSON.t>>,
}

let make = (
  ~name: option<string>=None,
  ~parts: array<Part.t>,
  ~metadata: option<Dict.t<JSON.t>>=None,
): t => {
  {
    artifactId: Agent__Id.make(),
    name,
    parts,
    metadata,
  }
}

// Accessor for getting parts
let getParts = (artifact: t): array<Part.t> => artifact.parts
let getId = (artifact: t): Agent__Id.t => artifact.artifactId
