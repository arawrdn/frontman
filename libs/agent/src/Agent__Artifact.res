// Artifact - opaque type with safe construction

type t = {
  artifactId: Agent__Id.t,
  name: option<string>,
  parts: array<Agent__Part.t>,
  metadata: option<Dict.t<JSON.t>>,
}

let make = (
  ~name: option<string>=None,
  ~parts: array<Agent__Part.t>,
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
let getParts = (artifact: t): array<Agent__Part.t> => artifact.parts
let getId = (artifact: t): Agent__Id.t => artifact.artifactId
