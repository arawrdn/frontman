// Filesystem tools for agent

type toolResult<'a> = result<'a, string>
module Bindings = AskTheLlmBindings
// Read file contents
let readFile = async (projectRoot: string, relativePath: string): toolResult<string> => {
  let fullPath = Bindings.Path.join([projectRoot, relativePath])

  try {
    let content = await Bindings.Fs.Promises.readFile(fullPath)
    Ok(content)
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to read file ${relativePath}: ${message}`)
    }
  }
}

// Write file contents
let writeFile = async (projectRoot: string, relativePath: string, content: string): toolResult<
  unit,
> => {
  let fullPath = Bindings.Path.join([projectRoot, relativePath])

  try {
    await Bindings.Fs.Promises.writeFile(fullPath, content)
    Ok()
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to write file ${relativePath}: ${message}`)
    }
  }
}

type fileEntry = {
  name: string,
  path: string,
  isFile: bool,
  isDirectory: bool,
}

// List files in directory
let listFiles = async (projectRoot: string, relativePath: string): toolResult<array<fileEntry>> => {
  let fullPath = Bindings.Path.join([projectRoot, relativePath])

  try {
    let entries = await Bindings.Fs.Promises.readdir(fullPath)

    // Get stats for each entry
    let entriesWithStats = await entries
    ->Array.map(async name => {
      let entryPath = Bindings.Path.join([fullPath, name])
      let stats = await Bindings.Fs.Promises.stat(entryPath)

      {
        name,
        path: Bindings.Path.join([relativePath, name]),
        isFile: Bindings.Fs.isFile(stats),
        isDirectory: Bindings.Fs.isDirectory(stats),
      }
    })
    ->Promise.all

    Ok(entriesWithStats)
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to list files in ${relativePath}: ${message}`)
    }
  }
}

// Check if file exists
let fileExists = async (projectRoot: string, relativePath: string): bool => {
  let fullPath = Bindings.Path.join([projectRoot, relativePath])

  try {
    await Bindings.Fs.Promises.access(fullPath, Bindings.Fs.f_OK)
    true
  } catch {
  | _ => false
  }
}
