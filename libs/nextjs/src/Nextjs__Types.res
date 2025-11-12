type rec sourceLocation = {
  componentName: string,
  tagName: string,
  file: string,
  line: int,
  column: int,
  parent: option<sourceLocation>,
}
let sourceLocationSchema = S.recursive("SourceLocation", sourceLocationSchema => {
  S.object(s => {
    componentName: s.field("id", S.string),
    tagName: s.field("tagName", S.string),
    file: s.field("file", S.string),
    line: s.field("line", S.int),
    column: s.field("column", S.int),
    parent: s.field("parent", S.option(sourceLocationSchema)),
  })
})

@schema
type selectedElement = {
  selector: option<string>,
  screenshot: option<string>,
  sourceLocation: option<sourceLocation>,
}

type rec figmaNode = {
  id: string,
  name: string,
  @as("type") type_: string,
  css: option<Dict.t<string>>,
  width: option<float>,
  height: option<float>,
  x: option<float>,
  y: option<float>,
  visible: option<bool>,
  locked: option<bool>,
  children: option<array<figmaNode>>,
}

let figmaNodeSchema = S.recursive("FigmaNode", figmaNodeSchema => {
  S.object(s => {
    id: s.field("id", S.string),
    name: s.field("name", S.string),
    type_: s.field("type", S.string),
    css: s.field("css", S.option(S.dict(S.string))),
    width: s.field("width", S.option(S.float)),
    height: s.field("height", S.option(S.float)),
    x: s.field("x", S.option(S.float)),
    y: s.field("y", S.option(S.float)),
    visible: s.field("visible", S.option(S.bool)),
    locked: s.field("locked", S.option(S.bool)),
    children: s.field("children", S.option(S.array(figmaNodeSchema))),
  })
})

@schema
type chat = {
  message: string,
  taskId: string,
  selectedElement: option<selectedElement>,
  selectedFigmaNode: option<figmaNode>,
}
