# Ask-the-LLM Agent Core

Agent core for Ask-the-LLM framework. Handles code editing requests using Vercel AI SDK with Claude 3.5 Sonnet.

## Architecture

- **Language**: ReScript compiled to Node.js
- **Communication**: STDIO (JSON events via event-bus)
- **LLM**: Vercel AI SDK with Claude 3.5 Sonnet
- **State**: Stateful agent maintains conversation history across tool calls
- **Agent Loop**: Continues calling LLM until it stops requesting tools

## Usage

### Start Agent

```bash
node src/Agent.res.mjs --project-root=/path/to/project
```

The agent will:
1. Initialize with the specified project root
2. Load filesystem tools (read_file, write_file, list_files)
3. Listen for user requests on STDIN
4. Send responses on STDOUT

### STDIO Protocol

**Input (Plugin → Agent):**
```json
{
  "type": "user_request",
  "requestId": "req-123",
  "selectedElement": {
    "component": "Button",
    "filePath": "src/components/Button.tsx",
    "lineNumber": 10,
    "props": {},
    "styles": {}
  },
  "userMessage": "make the button bigger",
  "context": {
    "projectRoot": "/path/to/project",
    "componentSource": "...",
    "componentTree": null,
    "types": null,
    "fileStructure": null,
    "buildErrors": null
  }
}
```

**Output (Agent → Plugin):**
```json
{
  "type": "status",
  "requestId": "req-123",
  "message": "Reading component file..."
}
```

```json
{
  "type": "response",
  "requestId": "req-123",
  "message": "Updated button size by increasing padding",
  "filesChanged": ["src/components/Button.tsx"]
}
```

## Development

### Build
```bash
make build
```

### Run
```bash
make dev  # or: node src/Agent.res.mjs --project-root=.
```

## Testing

Standalone integration tests that spawn the agent as a subprocess. Tests use real LLM calls (no mocking) to catch prompt/integration issues.

```bash
make test              # Run all tests
make test-watch        # Watch mode
export ANTHROPIC_API_KEY=sk-ant-...  # Required
```

**Why subprocess testing?** Matches production environment and enables testing as if running in a different codebase.

**Test fixtures:** Committed sample projects in `test/fixtures/` - see `test/fixtures/README.md`

**Adding tests:** Follow patterns in `test/Integration__AgentCore.test.res`

## Environment Variables

- `ANTHROPIC_API_KEY` - Required for Claude API access

## Tools

The agent has three built-in filesystem tools:

1. **read_file**: Read file contents
   - Parameter: `relativePath` (string)
   - Returns: File contents as string

2. **write_file**: Write file contents
   - Parameters: `relativePath` (string), `content` (string)
   - Returns: Success message

3. **list_files**: List files in directory
   - Parameter: `directory` (string)
   - Returns: Newline-separated list of file names

## How It Works

1. **Initialization**: Agent loads tools and creates AI SDK model
2. **Request Processing**:
   - Receive user request via STDIN
   - Build initial conversation with system prompt + user message + context
   - Enter agent loop
3. **Agent Loop** (while-true):
   - Send messages to LLM with tools available
   - Stream responses and handle tool calls
   - Execute tools (read/write files)
   - Continue until LLM returns finishReason="stop"
4. **Response**: Send final message and changed files list

## Architecture Details

### Modules

- `Agent__Core` - Main agent initialization and lifecycle
- `Agent__Loop` - Agent loop with conversation history
- `Agent__StreamProcessor` - Handles Vercel AI SDK stream events
- `Agent__Tools__Registry` - Tool definitions with Sury validation
- `Agent__Bindings__VercelAI` - Vercel AI SDK bindings
- `Agent__Events` - Event schemas for Plugin communication
- `Agent__Bus__Plugin` - STDIO communication layer

### Agent Loop Flow

```
User Request → System Prompt → Agent Loop:
  ├─> Stream from LLM
  ├─> Process stream events
  ├─> Execute tool calls
  ├─> Add results to history
  ├─> Check finish reason
  └─> Continue or stop
```

## References

- Implementation plan: `thoughts/shared/plans/2025-10-13-agent-loop-integration.md`
- Vercel AI SDK: https://sdk.vercel.ai/
- Pattern adapted from OpenCode's agent loop
