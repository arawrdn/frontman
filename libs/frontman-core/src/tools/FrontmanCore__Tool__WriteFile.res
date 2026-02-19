// Write file tool - writes content to a file (text or binary via image_ref)

module Fs = FrontmanBindings.Fs
module NodeBuffer = FrontmanBindings.NodeBuffer
module Tool = FrontmanFrontmanProtocol.FrontmanProtocol__Tool
module PathContext = FrontmanCore__PathContext

let name = "write_file"
let visibleToAgent = true
let description = `Writes content to a file.

Parameters:
- path (required): Path to file - either relative to source root or absolute (must be under source root)
- content: Text content to write (mutually exclusive with image_ref)
- image_ref: URI of a user-attached image to save (e.g., "attachment://att_abc123/photo.png"). Use this to save images the user has pasted into the chat. Mutually exclusive with content.
- encoding: Set to "base64" when writing binary data (used internally when image_ref is resolved)

Provide either content OR image_ref, not both.
Creates parent directories if they don't exist. Overwrites existing files.
The _context field provides path resolution details for debugging.`

@schema
type input = {
  path: string,
  content?: string,
  @s.describe("URI of a user-attached image to save to disk")
  image_ref?: string,
  @s.describe("Set to 'base64' for binary content (used when image_ref is resolved)")
  encoding?: string,
}

@schema
type pathContext = {
  sourceRoot: string,
  resolvedPath: string,
  relativePath: string,
}

@schema
type output = {
  @s.meta({description: "Path resolution context for debugging"})
  _context?: pathContext,
}

let execute = async (ctx: Tool.serverExecutionContext, input: input): Tool.toolResult<output> => {
  // Validate: must have content or image_ref, not both
  switch (input.content, input.image_ref) {
  | (None, None) => Error("Either content or image_ref must be provided")
  | (Some(_), Some(_)) => Error("Provide either content or image_ref, not both")
  | _ =>
    switch PathContext.resolve(~sourceRoot=ctx.sourceRoot, ~inputPath=input.path) {
    | Error(err) => Error(PathContext.formatError(err))
    | Ok(result) =>
      let dirPath = PathContext.dirname(result)
      try {
        let _ = await Fs.Promises.mkdir(dirPath, {recursive: true})

        // If encoding is base64, write as binary; otherwise write as text
        switch input.encoding {
        | Some("base64") =>
          let base64Content = input.content->Option.getOrThrow
          let buffer = NodeBuffer.fromBase64(base64Content)
          await Fs.Promises.writeFileBuffer(result.resolvedPath, buffer)
        | _ =>
          let textContent = input.content->Option.getOrThrow
          await Fs.Promises.writeFile(result.resolvedPath, textContent)
        }

        Ok({
          _context: {
            sourceRoot: result.sourceRoot,
            resolvedPath: result.resolvedPath,
            relativePath: result.relativePath,
          },
        })
      } catch {
      | exn =>
        let msg = exn->JsExn.fromException->Option.flatMap(JsExn.message)->Option.getOr("Unknown error")
        Error(`Failed to write file ${input.path}: ${msg}`)
      }
    }
  }
}
