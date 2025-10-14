# Ask-the-LLM Architecture Document

## 1. Overview

Ask-the-LLM is a framework-integrated AI coding agent that embeds directly into web development frameworks, providing real-time access to compilation errors, runtime logs, and framework-specific context to assist developers with coding tasks.

## 2. System Architecture

### 2.1 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                Developer's Application                           │
│                (Next.js, Vite, etc.)                            │
│                                                                  │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Injected Agent UI                          │    │
│  └────────────────────────────────────────────────────────┘    │
│                           ↕ WebSocket/HTTP                       │
│  ┌────────────────────────────────────────────────────────┐    │
│  │           Framework Integration Plugin                  │    │
│  │  • Context collection and storage                       │    │
│  │  • Spawns agent process                                 │    │
│  │  • Injects UI components                                │    │
│  │  • Manages communication                                │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
                           ↕ STDIO
┌─────────────────────────────────────────────────────────────────┐
│                    Agent Core                                    │
│  • Stateless request processing                                 │
│  • Agentic decision loop                                        │
│  • LLM integration                                              │
│  • Tool execution                                               │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Overview

The system consists of two primary components:

**Agent Core**: A stateless executable that processes requests with provided context, implements the agentic loop, integrates with LLM providers, and executes tools.

**Framework Integration Plugin**: A framework-specific library that bridges the developer's application with the agent core, collecting and maintaining framework context, managing the agent lifecycle.

## 3. Components

### 3.1 Agent Core

**Location:** `apps/agent`

**Type:** Executable (ReScript/Node.js)

**Purpose:** Stateless decision engine responsible for processing requests with provided context.

**Key Responsibilities:**
- Process requests with attached context
- Execute agentic decision loop
- Integrate with LLM APIs (Claude, GPT, etc.)
- Execute tools (file operations, code analysis)
- Request additional context when needed
- Send responses and commands

**State Model:** Stateless - does not maintain framework context between requests. All necessary context is provided by the plugin either with the initial request or upon explicit request.

### 3.2 Framework Integration Plugin

**Location:** `libs/nextjs-plugin` (initial implementation for Next.js)

**Type:** Library (ReScript/Node.js)

**Purpose:** Bridge between the developer's framework and the agent core. Maintains framework state and context.

**Key Responsibilities:**
- Spawn and manage agent process lifecycle
- Collect and store framework-specific context (compilation errors, logs, routes)
- Inject UI components into the running application
- Provide API endpoints for UI communication
- Bundle relevant context with user requests
- Respond to agent context requests
- Execute agent-requested commands

**State Model:** Stateful - maintains current framework state, error history, logs, and other context.

### 3.3 Bindings Library

**Location:** `libs/bindings`

**Purpose:** Shared ReScript bindings for Node.js APIs (fs, path, process, child_process, streams). Eliminates duplication across apps/libs.

## 4. Communication Architecture

### 4.1 Inter-Process Communication

**Agent Core ↔ Framework Plugin**: STDIO with JSON-encoded messages

- **Protocol:** Standard input/output streams
- **Format:** JSON (with Sury type-safe encoding in ReScript)
- **Direction:** Bidirectional

**Framework Plugin ↔ UI**: WebSocket/HTTP

- **Protocol:** WebSocket for real-time updates, HTTP for commands
- **Format:** JSON
- **Direction:** Bidirectional

### 4.2 Message Types

**Plugin → Agent:**
- User requests with bundled context
- Context responses (when agent requests specific context)
- Command execution results

**Agent → Plugin:**
- Response messages
- File operation requests (read, write, edit)
- Command execution requests
- Context requests (for specific information)
- Status updates

## 5. Data Flow

### 5.1 User Interaction Flow

1. User interacts with agent UI (embedded in their application)
2. UI communicates with framework plugin via WebSocket/HTTP
3. Framework plugin bundles relevant context with user request
4. Plugin sends request + context to agent via STDIO
5. Agent processes request using provided context, LLM, and tools
6. Agent may request additional context if needed
7. Plugin responds with requested context
8. Agent sends response/commands back via STDIO
9. Plugin executes commands and updates UI
10. User receives response

### 5.2 Context Management Flow

**Context Collection (Plugin):**
1. Framework emits events (compilation, logging, routing)
2. Plugin collectors capture and store events
3. Context remains in plugin memory
4. Context is attached to requests when relevant

**Context Retrieval (Agent):**
1. Agent receives request with initial context
2. Agent determines if additional context is needed
3. Agent sends context request to plugin
4. Plugin retrieves and sends requested context
5. Agent continues processing with full context

## 6. Technology Stack

### 6.1 Agent Core
- **Language:** ReScript
- **Runtime:** Node.js
- **Communication:** STDIO with JSON (Sury encoding)
- **State:** Stateless

### 6.2 Framework Integration
- **Language:** ReScript
- **Runtime:** Node.js
- **UI Framework:** React
- **Communication:** WebSocket/HTTP (UI), STDIO (Agent)
- **State:** Stateful (maintains framework context)

## 7. Deployment Architecture

### 7.1 Package Structure

```
ask-the-llm/
├── apps/
│   └── agent/              # Agent core executable
├── libs/
│   ├── bindings/           # Shared Node.js bindings
│   ├── event-bus/          # Event bus communication library
│   └── nextjs-plugin/      # Next.js integration library
└── examples/
    └── nextjs/             # Development/testing Next.js app
```

### 7.2 Installation Flow

1. Developer installs framework integration package (`npm install @ask-the-llm/nextjs-plugin`)
2. Developer configures framework to use plugin (one-line config change)
3. Developer starts their development server normally
4. Plugin initializes, spawns agent, injects UI
5. Agent becomes available for interaction

### 7.3 Development and Testing

The `examples/` directory contains framework applications used for development, testing, and demonstrating integration:

```
examples/
└── nextjs/              # Next.js application with plugin integrated
    ├── app/             # Next.js app router
    ├── next.config.js   # Uses plugin
    └── package.json     # Depends on local plugin
```

**Purpose:**
- Rapid iteration during development
- Integration testing with real framework
- Reference implementation for users
- Documentation through working examples

**Development Workflow:**
1. Make changes to plugin or agent code
2. Changes hot-reload in example app
3. Test integration in real environment
4. Validate before publishing

## 8. Context Strategy

### 8.1 Context Collection

The framework plugin continuously collects context from the running application:
- Compilation errors and warnings (captured when they occur)
- Runtime logs (buffered in memory)
- Route information (tracked on changes)
- Build status and performance metrics

### 8.2 Context Delivery

Context is delivered to the agent in two ways:

**Bundled with Request:** Common/relevant context is attached to initial user requests (recent errors, current route, etc.)

**On-Demand:** Agent requests specific context when needed (full log history, specific file content, detailed error traces)

## 9. Extensibility

### 9.1 Framework Support

The architecture supports multiple frameworks through isolated integration packages. Each framework integration implements the same communication protocol with the agent core, ensuring consistency across platforms.

### 9.2 Tool System

The agent core maintains a registry of tools that can be executed. Tools follow a standardized interface for execution and result reporting.

## 10. Error Handling and Resilience

### 10.1 Process Isolation

The agent runs as a separate process, ensuring that agent failures do not impact the developer's application.

### 10.2 Recovery Mechanisms

- Agent crashes trigger automatic restart by the framework plugin
- Plugin maintains context state across agent restarts
- LLM failures implement retry logic with exponential backoff
- File operation conflicts are detected and reported

---

**Document Version:** 1.2
**Last Updated:** 2025-10-06
**Classification:** Internal Architecture Documentation
