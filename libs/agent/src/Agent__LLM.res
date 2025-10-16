// LLM interface for chat interactions

type t = {
  model: Agent__Bindings__VercelAI.languageModel,
  tools: Dict.t<Agent__Bindings__VercelAI.toolDef>,
}

let make = (~model, ~tools) => {
  {model, tools}
}

let chat = async (llm: t, messages: array<Agent__Message.t>): string => {
  // Convert Agent__Message.t to Vercel AI format
  let vercelMessages = messages->Array.map(msg => {
    let role = switch msg->Agent__Message.getRole {
    | User => "user"
    | Agent => "assistant"
    }

    let content =
      msg
      ->Agent__Message.getParts
      ->Array.map(part => {
        switch part {
        | Text(textPart) => textPart->Agent__Part.TextPart.getText
        | File(filePart) => {
            let file = filePart->Agent__Part.FilePart.getFile
            let name = file->Agent__Part.File.getName->Option.getOr("unnamed")
            let mimeType = file->Agent__Part.File.getMimeType
            `File: ${name}, MimeType: ${mimeType}`
          }
        | Data(dataPart) => {
            let data = dataPart->Agent__Part.DataPart.getData
            `Data: ${data->JSON.stringify}`
          }
        }
      })
      ->Array.join("\n")

    {
      Agent__Bindings__VercelAI.role,
      content,
    }
  })

  // Call LLM
  let result = await Agent__Bindings__VercelAI.streamText({
    model: llm.model,
    messages: vercelMessages,
    tools: Some(llm.tools),
    maxSteps: None,
  })

  await result->Agent__Bindings__VercelAI.text
}
