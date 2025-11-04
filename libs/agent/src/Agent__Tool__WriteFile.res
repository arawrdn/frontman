module Bindings = AskTheLlmBindings

let name = "write_file"
let description = "Write contents to a file in the project"

@schema
type input = {
  relativePath: string,
  content: string,
}

// Use a literal null type instead of unit since unit cannot be converted to JSON
// S.literal with null value properly serializes to JSON null
type output
external nullValue: output = "null"
let outputSchema = S.literal(nullValue)

let decodeInput: JSON.t => result<input, S.error> = json => {
  try {
    Ok(json->S.parseJsonOrThrow(inputSchema))
  } catch {
  | S.Error(error) => Error(error)
  }
}

let encodeOutput = (output: output): JSON.t => {
  output->S.reverseConvertToJsonOrThrow(outputSchema)
}

let execute = async (ctx: Agent__ToolExecutionContext.t, input: input): Agent__Tool.toolResult<
  output,
> => {
  let fullPath = Bindings.Path.join([ctx.projectRoot, input.relativePath])

  try {
    await Bindings.Fs.Promises.writeFile(fullPath, input.content)
    Ok(nullValue)
  } catch {
  | exn => {
      let message =
        exn
        ->JsExn.fromException
        ->Option.flatMap(JsExn.message)
        ->Option.getOr("Unknown error")
      Error(`Failed to write file ${input.relativePath}: ${message}`)
    }
  }
}
