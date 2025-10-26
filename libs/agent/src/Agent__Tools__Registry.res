// Tool registry - manages agent tools

// Tool input types
type readFileInput = {relativePath: string}

type writeFileInput = {
  relativePath: string,
  content: string,
}

type listFilesInput = {directory: string}

// GADT for tools to ensure input/output type correspondence
type rec tool =
  | Tool({
      name: string,
      description: string,
      inputSchema: S.t<'input>,
      execute: 'input => promise<result<string, string>>,
    }): tool

type t = array<tool>

// Create the tool registry with all available tools
let make = (projectRoot: string): t => {
  [
    // read_file tool
    Tool({
      name: "read_file",
      description: "Read contents of a file from the project",
      inputSchema: S.object((s): readFileInput => {
        relativePath: s.field("relativePath", S.string),
      }),
      execute: async input => {
        await Agent__Tools__Filesystem.readFile(projectRoot, input.relativePath)
      },
    }),
    // write_file tool
    Tool({
      name: "write_file",
      description: "Write contents to a file in the project",
      inputSchema: S.object((s): writeFileInput => {
        relativePath: s.field("relativePath", S.string),
        content: s.field("content", S.string),
      }),
      execute: async input => {
        let result = await Agent__Tools__Filesystem.writeFile(
          projectRoot,
          input.relativePath,
          input.content,
        )
        switch result {
        | Ok() => Ok(`Successfully wrote ${input.relativePath}`)
        | Error(err) => Error(err)
        }
      },
    }),
    // list_files tool
    Tool({
      name: "list_files",
      description: "List files in a directory",
      inputSchema: S.object((s): listFilesInput => {
        directory: s.field("directory", S.string),
      }),
      execute: async input => {
        let result = await Agent__Tools__Filesystem.listFiles(projectRoot, input.directory)
        switch result {
        | Ok(entries) => {
            let names = entries->Array.map(e => e.name)->Array.join("\n")
            Ok(names)
          }
        | Error(err) => Error(err)
        }
      },
    }),
  ]
}
