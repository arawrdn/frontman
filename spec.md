# Ask-the-LLM MVP Specification

**Version:** 1.0
**Target Ship Date:** 2 weeks from start
**Last Updated:** 2025-10-13

---

## Executive Summary

Ask-the-LLM is a framework-integrated AI coding agent that enables developers to visually edit their web applications using natural language. The MVP focuses on delivering client-side visual editing in existing React/Next.js codebases with best-in-class quality through comprehensive app context awareness.

**Core Value Proposition:** Developers can point at UI elements in their running app and describe changes in plain English, and the agent makes high-quality code edits backed by full framework context (component source, types, props, styles, structure).

---

## MVP Scope & Goals

### Success Criteria
- **Timeline:** Ship in 2 weeks
- **Validation:** Successfully onboard 2 real projects that can use the tool
- **Quality Bar:** Edits must be production-grade quality due to comprehensive context

### Core Features (In Scope)
1. **Visual Element Selection:** Click UI elements in running app to select for editing
2. **Chat Interface:** Natural language requests for code changes
3. **Context-Aware Editing:** Agent has access to:
   - Component source code
   - Component tree/hierarchy
   - Props/state (runtime data)
   - Styling context (CSS/Tailwind/styled-components)
   - File structure and imports
   - TypeScript types
   - Build errors/warnings
4. **Edit Operations:**
   - Style changes (colors, spacing, layout)
   - Content changes (text, props, values)
   - Structure changes (add/remove elements, reorder)
5. **Framework Support:** Next.js and React (Vite/Create React App)
6. **Language Support:** TypeScript only

### Explicitly Out of Scope
- Authentication/user accounts
- Undo/history of changes
- Collaboration (multiple developers)
- Git integration (auto-commits)
- Testing integration
- Production deployment features
- Creating new components
- Installing/modifying dependencies
- JavaScript-only projects (TS required)

---

## Architecture Overview

### System Components

```
┌─────────────────────────────────────────────────────────────────┐
│                    Developer's Browser                           │
│                                                                  │
│  ┌──────────────────┐  ┌────────────────────────────────────┐  │
│  │   Chat UI        │  │   App (iframe)                      │  │
│  │   (left pane)    │  │   • Visual selection active         │  │
│  │                  │  │   • Hot reload enabled              │  │
│  └──────────────────┘  └────────────────────────────────────┘  │
│           ↕ WebSocket/HTTP                ↕ Context injection   │
└─────────────────────────────────────────────────────────────────┘
                           ↕
┌─────────────────────────────────────────────────────────────────┐
│                 Next.js Dev Server Process                       │
│                                                                  │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Next.js Middleware                            │  │
│  │  • Serves /ask-the-llm route                              │  │
│  │  • Manages WebSocket connections                          │  │
│  │  • Collects context (build-time + runtime)                │  │
│  │  • Calls Agent library directly (in-process)              │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           ↕ Direct function calls               │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │              Agent Library (libs/agent)                    │  │
│  │  • Stateful agent instance                                │  │
│  │  • Direct filesystem access to project                    │  │
│  │  • Agentic decision loop                                  │  │
│  │  • OpenAI GPT-4o integration with tool calling            │  │
│  │  • Executes tools:                                        │  │
│  │    - read_file, write_file, list_files                    │  │
│  │    - get_context (from middleware)                        │  │
│  │  • Context-aware code generation                          │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           ↕ Direct filesystem I/O               │
└─────────────────────────────────────────────────────────────────┘
                           ↕
                    [Project Files]
```

### Key Architectural Decisions

1. **100% Local:** No cloud components, runs entirely in developer's environment
2. **In-Process Agent Library:** Agent runs as a library within the Next.js dev server process (simple, no IPC overhead)
3. **Direct Function Calls:** Middleware calls agent library functions directly (may extract to subprocess later for isolation)
4. **Agent Has Direct Filesystem Access:** Agent executes file operations directly via Node.js fs APIs
5. **Hybrid Context Collection:** Build-time hooks + runtime injection to capture complete picture
6. **Full File Rewrites:** Agent generates complete file contents (not AST-based diffs) for simplicity
7. **Visual Selection Already Built:** DOM-to-source mapping and visual feedback already implemented

---

## Technical Specifications

### Technology Stack

**Agent Library (libs/agent):**
- Language: ReScript
- Runtime: Node.js (runs in-process with Next.js dev server)
- Communication: Direct function calls (in-process)
- Filesystem: Direct access to project files via Node.js fs APIs
- LLM: OpenAI GPT-4o API with function/tool calling
- State: Stateful (maintains conversation context across requests)

**Next.js Middleware (libs/nextjs):**
- Language: ReScript
- Runtime: Node.js (embedded in Next.js dev server)
- Communication: Direct function calls to agent library, WebSocket/HTTP to UI
- Integration Points: Next.js middleware + build hooks + runtime injection

**UI:**
- Framework: React (minimal custom components)
- Layout: Split-screen (chat + iframe)
- Styling: TBD (delegated to UI developer)
- Communication: WebSocket for streaming, HTTP for commands

### Agent Tool Execution Model

The agent has a tool registry that it executes internally via OpenAI function calling:

**Filesystem Tools (executed directly by agent):**
- `read_file(path)` - Read file contents from project
- `write_file(path, content)` - Write complete file contents
- `list_files(directory)` - List files in directory
- `search_files(pattern)` - Search for files matching pattern

**Context Request Tools (callbacks to middleware):**
- `get_component_props(filePath, componentName)` - Request runtime props from middleware
- `get_component_tree(componentName)` - Request component hierarchy from middleware
- `get_build_errors()` - Request current compilation errors from middleware

**Flow:**
1. Middleware calls agent library function with request and initial context bundle
2. Agent decides what tools to call (LLM function calling)
3. Filesystem tools execute immediately (Node.js fs APIs)
4. Context request tools call back to middleware via provided callback functions
5. Agent continues with tool results
6. Agent returns response to middleware (function return value or callback)

### Context Collection Strategy

**Build-Time Collection (via framework plugin hooks):**
- Component source code locations
- TypeScript type information (via TS compiler API)
- File structure and imports (via module graph)
- Build errors/warnings (captured from compilation)

**Runtime Collection (via injected code in app):**
- Component tree/hierarchy (React DevTools protocol or similar)
- Props/state values (runtime inspection)
- DOM element to component mapping (React metadata + source maps - already built)
- Applied styles (computed styles from DOM)

**Context Storage:**
- Middleware maintains in-memory context store
- Middleware passes relevant context when calling agent library
- Agent can request additional context via callback functions

### Communication Protocols

**Middleware → Agent (Function Call):**
```typescript
// Agent library function signature
agent.processRequest({
  requestId: "req-123",
  selectedElement: {
    component: "Button",
    filePath: "src/components/Button.tsx",
    lineNumber: 42,
    props: {variant: "primary", onClick: "..."},
    styles: {backgroundColor: "#007bff", ...}
  },
  userMessage: "make this button bigger",
  context: {
    projectRoot: "/Users/dev/my-app",
    componentSource: "...",
    componentTree: [...],
    types: {...},
    fileStructure: {...},
    buildErrors: [...]
  },
  // Callbacks for context requests and status updates
  onStatus: (message) => { /* send to UI via WebSocket */ },
  getAdditionalContext: (contextType, params) => { /* return context */ }
})
```

**Agent → Middleware (Return Value/Callbacks):**
```typescript
// Status updates via callback
onStatus("Analyzing component structure...")
onStatus("Writing files...")

// Context requests via callback
const props = await getAdditionalContext("component_props", {
  filePath: "src/components/Card.tsx"
})

// Final response (function return)
return {
  success: true,
  message: "I've updated the button size by increasing padding and font size.",
  filesChanged: ["src/components/Button.tsx"]
}

// Or error response
return {
  success: false,
  error: "Failed to parse component: syntax error on line 23"
}
```

**UI ↔ Middleware (WebSocket/HTTP):**
- WebSocket for streaming agent status/responses
- HTTP POST for sending user requests
- UI sends element selection + user message
- Middleware forwards agent status/responses to UI via WebSocket

### Installation & Setup

**Package Structure:**
- `@ask-the-llm/agent` - Agent library (core logic)
- `@ask-the-llm/nextjs` - Next.js middleware (integrates agent library)
- `@ask-the-llm/react-vite` - Vite plugin (future, if needed)

**Installation Steps:**
1. `npm install @ask-the-llm/nextjs`
2. Add plugin configuration to `next.config.js`:
   ```js
   const { withAskTheLLM } = require('@ask-the-llm/nextjs')

   module.exports = withAskTheLLM({
     // existing next config
   })
   ```
3. Add OpenAI API key to `.env.local`:
   ```
   OPENAI_API_KEY=sk-...
   ```
4. Start dev server: `npm run dev`
5. Navigate to `http://localhost:3000/ask-the-llm`

**Distribution for MVP:**
- Git dependency installation from GitHub repo
- No npm publish required for 2-project validation

---

## Component Breakdown

### 1. Agent Library (`libs/agent`)

**Owner:** BlueHotDog
**Language:** ReScript
**Timeline:** Week 1-2

**Responsibilities:**
- Export stateful agent instance creation function
- Maintain conversation context across requests
- Execute agentic decision loop:
  1. Parse user request + context
  2. Determine editing strategy (via LLM reasoning)
  3. Call tools as needed (via OpenAI function calling)
  4. Execute filesystem tools directly (read/write files)
  5. Request additional context from middleware via callbacks
  6. Generate code changes
  7. Write files directly
  8. Return response
- Tool registry:
  - `read_file(path)` - Direct filesystem read
  - `write_file(path, content)` - Direct filesystem write
  - `list_files(dir)` - Direct filesystem list
  - `get_context(type, params)` - Call middleware callback for context

**Key Implementation Details:**
- Exports `createAgent(config)` function
- Receives project root path in config
- Uses Node.js `fs` module for file operations
- Uses OpenAI SDK with function/tool calling
- Full file rewrites (not diffs) for simplicity
- Prompt engineering to leverage all provided context
- Handles errors gracefully (TS errors, file not found, etc.)
- Minimal automated tests for core loop and tool execution

### 2. Next.js Middleware (`libs/nextjs`)

**Owner:** BlueHotDog
**Language:** ReScript
**Timeline:** Week 1-2

**Responsibilities:**
- Initialize on dev server startup
- Create and manage agent library instance
- Inject build-time hooks (webpack/Next.js compilation hooks)
- Inject runtime code into app for:
  - Visual element selection feedback (already built)
  - Component tree inspection
  - Props/state capture
  - DOM-to-source mapping (already built)
- Serve `/ask-the-llm` route with UI
- Handle WebSocket/HTTP connections from UI
- Collect and maintain context store (in-memory)
- Bundle context and call agent library with user requests
- Provide callback functions for agent to request additional context
- Forward agent status updates to UI via WebSocket
- Watch for file changes (framework's hot reload handles refresh)

**Key Implementation Details:**
- Next.js middleware architecture (`withAskTheLLM` wrapper)
- In-memory context storage with efficient lookup
- Imports and calls agent library directly (in-process)
- Read `OPENAI_API_KEY` from process.env, pass to agent
- Provides callbacks to agent for status updates and context requests
- Does NOT execute file operations (agent library does this)

### 3. Chat UI (`libs/ui` or embedded in plugin)

**Owner:** Delegated UI developer (parallel work)
**Language:** React + TypeScript
**Timeline:** Week 1-2

**Responsibilities:**
- Split-screen layout:
  - Left: Chat interface for user messages and agent responses
  - Right: iframe embedding the user's app
- Chat features:
  - Text input for user requests
  - Display agent responses (with streaming status updates)
  - Show selected element info (component name, file path)
  - Show agent status ("Analyzing...", "Writing files...", etc.)
- Element selection:
  - Enable selection mode (already implemented)
  - Highlight selected element
  - Send selection data to plugin
- Minimal styling (functional over beautiful for MVP)

**Key Implementation Details:**
- Iframe embedding with selection overlay
- WebSocket connection to plugin for real-time status updates
- HTTP POST to send user requests with selection data
- Handle selection data from iframe (PostMessage or window refs)

---

## Integration Points

### Next.js Plugin Integration
- Hook into Next.js dev server initialization
- Add webpack/turbopack plugins for build-time context
- Inject middleware for `/ask-the-llm` route
- Inject client-side code bundle for selection/inspection

### Vite/React Plugin Integration
- Similar approach adapted for Vite plugin API
- Vite-specific hooks for build context
- Dev server middleware for routes

### Element Selection (Already Built)
- Leverage existing DOM-to-source mapping code
- Leverage existing visual feedback system
- Integration: Plugin injects this code into running app

---

## Agent Editing Strategy

### Context Utilization
For each request, agent receives:
1. **Selected Element Context:**
   - Component name and file path
   - Current source code
   - Runtime props/state
   - Applied styles
   - Position in component tree

2. **Surrounding Context:**
   - Parent/child components
   - Related files (imports/exports)
   - Type definitions
   - Global styles/theme

3. **Project Context:**
   - Project root path
   - File structure
   - Build errors/warnings

4. **User Intent:**
   - Natural language description
   - Selected element reference

### Code Generation Approach
1. Receive request with bundled context
2. LLM analyzes user request against element context
3. LLM decides which tools to call (OpenAI function calling)
4. Agent executes tools:
   - Read current file(s) via `read_file`
   - Analyze and generate new content
   - Write updated file(s) via `write_file`
5. Framework's hot reload picks up changes automatically
6. Agent sends response to plugin
7. Plugin forwards to UI

### Example Flow
```
User selects button → types "make it primary color" in chat

UI → Middleware (HTTP POST):
{selectedElement: {...}, message: "make it primary color"}

Middleware bundles context and calls agent library:
const response = await agent.processRequest({
  selectedElement: {component: "Button", filePath: "src/components/Button.tsx", props: {variant: "secondary"}},
  userMessage: "make it primary color",
  context: {projectRoot: "/Users/dev/app", componentSource: "...", ...},
  onStatus: (msg) => websocket.send({type: "status", message: msg}),
  getAdditionalContext: (type, params) => contextStore.get(type, params)
})

Agent (internal reasoning via LLM):
- User wants to change button to primary color
- Current variant is "secondary"
- Need to change prop or modify component

Agent calls tools (via OpenAI function calling):
1. read_file("src/components/Button.tsx") → gets full source
2. LLM generates new source with variant="primary"
3. write_file("src/components/Button.tsx", newSource) → writes directly
4. Calls onStatus("Updating button variant...")

Agent returns:
{success: true, message: "Changed button to primary color", filesChanged: ["src/components/Button.tsx"]}

Middleware → UI (WebSocket):
{type: "response", message: "Changed button to primary color", filesChanged: [...]}

Framework hot reload:
- Detects file change
- Recompiles
- Updates iframe automatically
```

---

## Testing Strategy

### Automated Testing (Minimal)
**Coverage:** Core paths only
**Timeline:** 1-2 days within sprint

**Test Scope:**
1. **Agent Library:**
   - Request parsing and processing
   - Tool execution (mock OpenAI, test file read/write)
   - Callback invocation (status updates, context requests)
   - Error handling (invalid requests, file errors)

2. **Middleware:**
   - Agent library initialization
   - Context collection basics
   - Function calls to agent library
   - Callback handling and WebSocket forwarding

3. **Integration:**
   - End-to-end: User request → middleware calls agent → agent writes file → response
   - One test per supported framework

**Not Testing:**
- UI components (manual testing only)
- All edge cases (defer to post-MVP)
- Performance/load testing
- Complex multi-file scenarios

### Manual Testing
- Test on 2-3 internal example apps
- Verify each edit type works (style, content, structure)
- Ensure hot reload works after changes
- Validate TypeScript errors don't break agent
- Test context request flow

---

## Data Flow Summary

### Full Request Cycle

```
1. User clicks element in iframe
   → Selection overlay activates (visual feedback)
   → Selection data captured

2. User types message in chat
   → Click send

3. UI → Plugin (WebSocket/HTTP):
   {elementData: {...}, message: "..."}

4. Middleware processes:
   → Look up element in context store
   → Bundle relevant context
   → Call agent library function

5. Middleware → Agent (Function Call):
   agent.processRequest({selectedElement: {...}, context: {...}, message: "...", onStatus, getAdditionalContext})

6. Agent processes:
   → Parse request
   → LLM decides strategy
   → Call tools (read files, analyze, write files)
   → Tools execute directly (filesystem I/O)
   → May request additional context from middleware via callbacks

7. Agent → Middleware (Callbacks + Return):
   onStatus("Analyzing component...")
   return {success: true, message: "Done!", filesChanged: [...]}

8. Middleware → UI (WebSocket):
   Forward status updates and final response

9. Framework hot reload:
   → Detects file changes
   → Recompiles
   → Updates iframe

10. User sees:
    → Status updates in chat
    → Final response message
    → Visual changes in iframe
```

---

## Timeline & Milestones

### Week 1
**Days 1-2:**
- [ ] Agent library scaffolding (ReScript project setup, function exports, filesystem tools)
- [ ] Middleware scaffolding (Next.js middleware structure, agent library integration)
- [ ] UI scaffolding (split-screen layout, iframe setup)

**Days 3-4:**
- [ ] Agent: OpenAI integration + tool calling (read/write file tools)
- [ ] Middleware: Build-time context collection hooks
- [ ] UI: Chat interface + element selection integration

**Days 5-7:**
- [ ] Agent: Code generation prompts and strategies
- [ ] Agent: Callback implementation for context requests and status updates
- [ ] Middleware: Runtime context injection
- [ ] Middleware: WebSocket/HTTP server for UI
- [ ] Middleware: Provide context callbacks to agent
- [ ] Integration: Wire all components together

### Week 2
**Days 8-10:**
- [ ] End-to-end testing and bug fixes
- [ ] Minimal automated tests
- [ ] README documentation
- [ ] Vite/CRA plugin (if Next.js done early)

**Days 11-12:**
- [ ] Polish and edge case handling
- [ ] Prepare example apps for testing
- [ ] Onboard first test project

**Days 13-14:**
- [ ] Onboard second test project
- [ ] Fix critical issues discovered
- [ ] Buffer for unexpected issues

---

## Success Criteria

### Must Have (Required for Ship)
- ✅ Developer can install via Git dependency
- ✅ Developer can run dev server and access `/ask-the-llm`
- ✅ Developer can select UI elements visually
- ✅ Developer can request style changes via chat
- ✅ Developer can request content changes via chat
- ✅ Developer can request structure changes via chat
- ✅ Agent executes file writes directly (no IPC overhead)
- ✅ Changes hot-reload automatically
- ✅ Agent produces TypeScript-valid code
- ✅ Works on at least Next.js projects
- ✅ 2 real projects successfully onboarded

### Nice to Have (Defer if Needed)
- ⚪ Streaming responses in chat UI
- ⚪ Support for Vite/CRA beyond Next.js
- ⚪ Syntax highlighting in chat
- ⚪ Error recovery flows
- ⚪ Performance optimizations

### Quality Bar
- Code changes must be production-grade (no placeholders, no broken TS)
- Agent must leverage provided context (not generic suggestions)
- Response time < 10 seconds for simple edits
- No crashes during normal usage

---

## Risk Mitigation

### High-Risk Areas
1. **Context Collection Complexity**
   - Mitigation: Start with file-based context, add runtime incrementally
   - Fallback: Reduce context scope if too complex

2. **Code Quality from LLM**
   - Mitigation: Rich prompts with full context, examples, constraints
   - Fallback: Manual fixes for test projects, iterate on prompts

3. **Framework Integration Fragility**
   - Mitigation: Test on multiple project structures early
   - Fallback: Document known limitations, fix post-MVP

4. **Agent State Management**
   - Mitigation: Proper error handling, graceful degradation
   - Fallback: Agent instance recreation on critical errors

5. **Timeline Slip**
   - Mitigation: Daily check-ins, ruthlessly cut scope if behind
   - Fallback: Ship with just Next.js, defer React/Vite

### Scope Cut Candidates (if timeline at risk)
- Vite/CRA support (keep Next.js only)
- Runtime context (use only build-time + file reads)
- Structure editing (keep only style + content)
- Automated tests (manual only)
- Context request callbacks (agent works with initial context only)

---

## Post-MVP Roadmap (Not in 2-week scope)

### Phase 2 (After validation)
- Undo/history
- Create new components
- Install dependencies
- Git integration (auto-commit changes)
- Multiple LLM provider support (Anthropic, local models)
- JavaScript support

### Phase 3 (Future)
- Collaboration features
- Testing integration
- Production deployment features
- More framework support (SvelteKit, Vue, etc.)
- Cloud-hosted agent option

---

## Appendix: Technical Notes

### Environment Variables
- `OPENAI_API_KEY` - Required, stored in user's framework env file (`.env.local` for Next.js)
- Middleware reads from `process.env.OPENAI_API_KEY` and passes to agent library

### Agent Initialization
```typescript
// Middleware initializes agent library at startup
import { createAgent } from '@ask-the-llm/agent'

const agent = createAgent({
  projectRoot: process.cwd(),
  openaiApiKey: process.env.OPENAI_API_KEY
})
```

Agent library maintains state and can execute file operations relative to project root.

### File Structure (Expected)
```
ask-the-llm/
├── libs/
│   ├── agent/              # Agent library (ReScript)
│   │   ├── src/
│   │   │   ├── Agent.res        # Main agent loop
│   │   │   ├── Agent__Tools.res # Tool execution (fs operations)
│   │   │   └── Agent__LLM.res   # OpenAI integration
│   │   └── package.json
│   ├── nextjs/             # Next.js middleware (ReScript)
│   │   ├── src/
│   │   │   ├── Nextjs.res           # Main middleware logic
│   │   │   ├── Nextjs__Context.res  # Context collection
│   │   │   └── Nextjs__Middleware.res # WebSocket/HTTP server
│   │   └── package.json
│   └── ui/                 # Chat UI components (React)
│       ├── src/
│       │   ├── SplitView.tsx
│       │   ├── Chat.tsx
│       │   └── Iframe.tsx
│       └── package.json
├── test/examples/
│   └── blog-starter/       # Test Next.js app
├── spec.md                 # This document
└── README.md               # Installation and usage docs
```

### Dependencies
- `openai` - OpenAI Node.js SDK (in agent library)
- `rescript` - ReScript compiler
- `@rescript/core` - ReScript standard library
- React + Next.js (peer dependencies for middleware)
- No special file operation libraries needed (use Node.js `fs` module)

---

**End of Specification**
