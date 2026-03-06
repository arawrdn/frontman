/**
 * ToolCallBlock - Main tool call display component
 *
 * Displays tool calls with human-readable names in purple-themed style:
 *   Get Routes
 *   target_path (as purple link)
 *
 * Supports compact mode for grouped display and expand/collapse for details.
 * Question tools are delegated to Client__QuestionToolBlock.
 */

// Tools that show a target inline (path, URL, etc.) instead of expandable body
let isFileTool = (toolName: string): bool => {
  switch Client__ToolLabels.cleanName(toolName) {
  | "read_file" | "write_file" | "list_files" | "list_dir" => true
  | _ => false
  }
}

let isInlineTool = (toolName: string): bool =>
  isFileTool(toolName) || Client__ToolLabels.cleanName(toolName) == "navigate"

// Extract navigate-specific target: URL for goto, action name for back/forward/refresh
let getNavigateTarget = (input: option<JSON.t>): option<string> => {
  switch input {
  | None => None
  | Some(json) =>
    switch JSON.Decode.object(json) {
    | None => None
    | Some(dict) =>
      let action = dict->Dict.get("action")->Option.flatMap(JSON.Decode.string)
      let url = dict->Dict.get("url")->Option.flatMap(JSON.Decode.string)
      switch (action, url) {
      | (Some("goto"), Some(u)) => Some(u)
      | (Some(a), _) => Some(a)
      | _ => None
      }
    }
  }
}

// Screenshot tool detection and image extraction
let isScreenshotTool = (toolName: string): bool =>
  Client__ToolLabels.cleanName(toolName) == "take_screenshot"

let getScreenshotSrc = (result: option<JSON.t>): option<string> => {
  result
  ->Option.flatMap(JSON.Decode.object)
  ->Option.flatMap(dict => dict->Dict.get("screenshot"))
  ->Option.flatMap(JSON.Decode.string)
  ->Option.flatMap(s => s != "" ? Some(s) : None)
}

// Extract target path/URL, defaulting to "./" for list/file operations
let getTarget = (toolName: string, input: option<JSON.t>): option<string> => {
  switch Client__ToolLabels.cleanName(toolName) {
  | "navigate" => getNavigateTarget(input)
  | _ =>
    switch Client__ToolLabels.extractTargetFromInput(input) {
    | Some(".") => Some("./")
    | Some(t) => Some(t)
    | None if isFileTool(toolName) => Some("./")
    | None => None
    }
  }
}

// Keep legacy alias so existing tests keep passing
let cleanToolName = Client__ToolLabels.cleanName

@react.component
let make = (
  ~toolName: string,
  ~state: Client__State__Types.Message.toolCallState,
  ~input: option<JSON.t>,
  ~inputBuffer: string,
  ~result: option<JSON.t>,
  ~errorText: option<string>,
  ~defaultExpanded: bool=false,
  ~compact: bool=false,
  ~messageId as _messageId: string="",
) => {
  // Question tool: delegate to dedicated component
  let isQuestionTool =
    Client__ToolLabels.cleanName(toolName)
    == FrontmanAiFrontmanClient.FrontmanClient__MCP__Tool.ToolNames.question

  switch isQuestionTool {
  | true => <Client__QuestionToolBlock state result errorText compact />
  | false => {
      let isLink = isInlineTool(toolName)
      let (isExpanded, setIsExpanded) = React.useState(() => defaultExpanded)
      let wasManuallyToggled = React.useRef(false)
      let (previewSrc, setPreviewSrc) = React.useState((): option<string> => None)

      // Sync with defaultExpanded prop unless manually toggled
      React.useEffect(() => {
        switch wasManuallyToggled.current {
        | true => ()
        | false => setIsExpanded(_ => defaultExpanded)
        }
        None
      }, [defaultExpanded])

      let target = getTarget(toolName, input)
      let isInProgress = state == InputStreaming || state == InputAvailable
      let hasError = Option.isSome(errorText)

      // Expandable tools show body when there's content
      let hasBody =
        !isLink &&
        (state == InputStreaming && inputBuffer != "" ||
        Option.isSome(input) ||
        Option.isSome(result) ||
        Option.isSome(errorText))

      // Toggle expansion handler
      let handleToggle = _ => {
        switch hasBody {
        | true =>
          setIsExpanded(prev => !prev)
          wasManuallyToggled.current = true
        | false => ()
        }
      }

      // Container classes - purple themed with rounded corners
      let containerClasses =
        [
          "group overflow-hidden",
          "animate-in fade-in duration-100",
          compact ? "rounded-lg" : "rounded-xl",
          compact ? "bg-[#8051CD]/15" : "bg-[#8051CD]/20",
          compact ? "border border-[#8051CD]/30" : "border border-[#8051CD]/40",
          compact ? "my-1 mx-2" : "my-2 mx-3",
          compact ? "px-3 py-2" : "px-4 py-3",
          hasBody ? "cursor-pointer" : "",
        ]
        ->Array.filter(s => s != "")
        ->Array.join(" ")

      // Body transition classes
      let bodyClasses = [
        "overflow-hidden frontman-collapse-transition",
        isExpanded ? "max-h-[300px] opacity-100" : "max-h-0 opacity-0",
      ]->Array.join(" ")

      <div className={containerClasses}>
        // Header - clickable to toggle expansion
        <div onClick={handleToggle}>
          // Human-readable tool name (e.g., "Get Routes", "Write File")
          <div className={`font-mono ${compact ? "text-[12px]" : "text-[13px]"}`}>
            <span className={isInProgress ? "shimmer-text text-zinc-200" : "text-zinc-200"}>
              {React.string(Client__ToolLabels.toTitleCase(toolName))}
            </span>
          </div>
          // Target path as purple link, or shimmer placeholder while streaming
          {switch (target, state, input) {
          | (_, InputStreaming, None) if isLink => {
              let placeholder = switch Client__ToolLabels.cleanName(toolName) {
              | "navigate" => "Waiting for URL..."
              | _ => "Waiting for file path..."
              }
              <div className={`mt-1 ${compact ? "text-[11px]" : "text-[12px]"}`}>
                <span className="font-mono shimmer-text text-zinc-500">
                  {React.string(placeholder)}
                </span>
              </div>
            }
          | (Some(t), _, _) =>
            <div className={`mt-1 ${compact ? "text-[11px]" : "text-[12px]"}`}>
              <span
                className={`font-mono ${hasError
                    ? "text-red-400"
                    : "text-[#8051CD] hover:text-[#9d7be0]"}`}>
                {React.string(t)}
              </span>
            </div>
          | _ => React.null
          }}
          // Error message if present (inline)
          {switch errorText {
          | Some(err) =>
            <div className="mt-2 text-[11px] text-red-400 font-mono">
              {React.string(err)}
            </div>
          | None => React.null
          }}
        </div>
        // Expandable body for non-file tools
        {switch hasBody {
        | true =>
          <div className={bodyClasses}>
            <div
              className={`mt-3 pt-3 border-t border-[#8051CD]/20 overflow-auto ${compact
                  ? "max-h-[120px] text-[10px]"
                  : "max-h-[150px] text-xs"}`}>
              {switch (state, input, inputBuffer) {
              | (InputStreaming, None, buf) if buf != "" =>
                <div className="mb-2">
                  <div className="text-[11px] text-zinc-500 mb-1">
                    {React.string("Input (streaming):")}
                  </div>
                  <pre
                    className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400">
                    {React.string(buf)}
                  </pre>
                </div>
              | (_, Some(json), _) =>
                <div className="mb-2">
                  <div className="text-[11px] text-zinc-500 mb-1">
                    {React.string("Input:")}
                  </div>
                  <pre
                    className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400">
                    {React.string(JSON.stringify(json, ~space=2))}
                  </pre>
                </div>
              | _ => React.null
              }}
              // Screenshot preview button when screenshot data is available
              {switch (isScreenshotTool(toolName), getScreenshotSrc(result)) {
              | (true, Some(src)) =>
                <div className="mb-2">
                  <button
                    type_="button"
                    onClick={e => {
                      ReactEvent.Mouse.stopPropagation(e)
                      setPreviewSrc(_ => Some(src))
                    }}
                    className="text-[11px] font-mono text-[#8051CD] hover:text-[#9d7be0] underline cursor-pointer">
                    {React.string("View Screenshot")}
                  </button>
                </div>
              | _ => React.null
              }}
              {switch (result, errorText) {
              | (Some(json), _) =>
                <div>
                  <div className="text-[11px] text-zinc-500 mb-1">
                    {React.string("Output:")}
                  </div>
                  <pre
                    className="font-mono text-[11px] whitespace-pre-wrap break-words text-zinc-400">
                    {React.string(JSON.stringify(json, ~space=2))}
                  </pre>
                </div>
              | (None, Some(_)) => React.null
              | _ if state == InputAvailable =>
                <div className="text-sm text-zinc-400 italic py-1">
                  {React.string("Executing...")}
                </div>
              | _ => React.null
              }}
            </div>
          </div>
        | false => React.null
        }}
        // Screenshot lightbox preview
        {switch previewSrc {
        | Some(src) =>
          <Client__ImagePreview src onClose={() => setPreviewSrc(_ => None)} />
        | None => React.null
        }}
      </div>
    }
  }
}
