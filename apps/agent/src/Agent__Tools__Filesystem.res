// Filesystem tools for agent

type toolResult<'a> = result<'a, string>

// Read file contents
let readFile = async (projectRoot: string, relativePath: string): toolResult<string> => {
  let fullPath = Bindings__Path.join([projectRoot, relativePath])

  try {
    let content = await Bindings__Fs.Promises.readFile(fullPath)
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
  let fullPath = Bindings__Path.join([projectRoot, relativePath])

  try {
    await Bindings__Fs.Promises.writeFile(fullPath, content)
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
  let fullPath = Bindings__Path.join([projectRoot, relativePath])

  try {
    let entries = await Bindings__Fs.Promises.readdir(fullPath)

    // Get stats for each entry
    let entriesWithStats = await entries
    ->Array.map(async name => {
      let entryPath = Bindings__Path.join([fullPath, name])
      let stats = await Bindings__Fs.Promises.stat(entryPath)

      {
        name,
        path: Bindings__Path.join([relativePath, name]),
        isFile: Bindings__Fs.isFile(stats),
        isDirectory: Bindings__Fs.isDirectory(stats),
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
  let fullPath = Bindings__Path.join([projectRoot, relativePath])

  try {
    await Bindings__Fs.Promises.access(fullPath, Bindings__Fs.f_OK)
    true
  } catch {
  | _ => false
  }
}
