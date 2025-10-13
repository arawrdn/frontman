// Filesystem tools for agent

type toolResult<'a> = result<'a, string>

// Read file contents
let readFile = async (projectRoot: string, relativePath: string): toolResult<string> => {
  let fullPath = Agent__Bindings__Path.join([projectRoot, relativePath])

  try {
    let content = await Agent__Bindings__Fs.Promises.readFile(fullPath)
    Ok(content)
  } catch {
  | exn => {
      let message = exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to read file ${relativePath}: ${message}`)
    }
  }
}

// Write file contents
let writeFile = async (projectRoot: string, relativePath: string, content: string): toolResult<unit> => {
  let fullPath = Agent__Bindings__Path.join([projectRoot, relativePath])

  try {
    await Agent__Bindings__Fs.Promises.writeFile(fullPath, content)
    Ok()
  } catch {
  | exn => {
      let message = exn
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
  let fullPath = Agent__Bindings__Path.join([projectRoot, relativePath])

  try {
    let entries = await Agent__Bindings__Fs.Promises.readdir(fullPath)

    // Get stats for each entry
    let entriesWithStats = await entries->Array.map(async name => {
      let entryPath = Agent__Bindings__Path.join([fullPath, name])
      let stats = await Agent__Bindings__Fs.Promises.stat(entryPath)

      {
        name,
        path: Agent__Bindings__Path.join([relativePath, name]),
        isFile: Agent__Bindings__Fs.isFile(stats),
        isDirectory: Agent__Bindings__Fs.isDirectory(stats),
      }
    })->Promise.all

    Ok(entriesWithStats)
  } catch {
  | exn => {
      let message = exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to list files in ${relativePath}: ${message}`)
    }
  }
}

// Check if file exists
let fileExists = async (projectRoot: string, relativePath: string): bool => {
  let fullPath = Agent__Bindings__Path.join([projectRoot, relativePath])

  try {
    await Agent__Bindings__Fs.Promises.access(fullPath, Agent__Bindings__Fs.f_OK)
    true
  } catch {
  | _ => false
  }
}
