// Message - opaque type with safe construction

module Part = Agent__Task__Message__Part
type id = Agent__Id.t
module System = {
  type t = {id: id, taskId?: Agent__Task__Id.t, content: string}
}
module User = {
  type contentParts = Text(Part.TextPart.t) | Image(Part.ImagePart.t) | File(Part.FilePart.t)
  type userContent = String(string) | List(array<contentParts>)
  type t = {content: userContent}
}

module Assistant = {
  type contentParts = Text(Part.TextPart.t) | ToolCall(Part.ToolCallPart.t)
  type t = String(string) | List(array<contentParts>)
}
//TODO(Danni) - continue here
type t = System(System.t) | User(User.t) | Assistant(Assistant.t)
