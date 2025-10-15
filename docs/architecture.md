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
│  │           Framework Integration Middleware              │    │
│  │  • Context collection and storage                       │    │
│  │  • Calls agent library directly (in-process)            │    │
│  │  • Injects UI components                                │    │
│  │  • Manages communication                                │    │
│  └────────────────────────────────────────────────────────┘    │
│                           ↕ Direct function calls               │
│  ┌────────────────────────────────────────────────────────┐    │
│  │              Agent Library (libs/agent)                 │    │
│  │  • Stateful request processing                          │    │
│  │  • Agentic decision loop                                │    │
│  │  • LLM integration                                      │    │
│  │  • Tool execution                                       │    │
│  └────────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

### 2.2 Component Overview

The system consists of two primary components:

**Agent Library**: A stateful library that processes requests with provided context, implements the agentic loop, integrates with LLM providers, and executes tools. Runs in-process with the framework for simplicity (may be extracted to a separate process later for isolation).

**Framework Integration Middleware**: A framework-specific library that bridges the developer's application with the agent library, collecting and maintaining framework context, calling the agent library directly via function calls.

## 3. Components

### 3.1 Agent Library

**Location:** `libs/agent`

**Type:** Library (ReScript/Node.js)

**Purpose:** Stateful agent engine responsible for processing requests with provided context.

**Key Responsibilities:**
- Process requests with attached context
- Execute agentic decision loop
- Integrate with LLM APIs (Claude, GPT, etc.)
- Execute tools (file operations, code analysis)
- Request additional context via callbacks
- Return responses and results

**State Model:** Stateful - maintains conversation context across requests. Framework context is provided by the middleware either with the initial request or via callback functions.

### 3.2 Framework Integration Middleware

**Location:** `libs/nextjs` (initial implementation for Next.js)

**Type:** Library (ReScript/Node.js)

**Purpose:** Bridge between the developer's framework and the agent library. Maintains framework state and context.

**Key Responsibilities:**
- Initialize and manage agent library instance
- Collect and store framework-specific context (compilation errors, logs, routes)
- Inject UI components into the running application
- Provide API endpoints for UI communication
- Bundle relevant context and call agent library functions
- Provide callback functions for agent to request additional context
- Forward agent status updates to UI

**State Model:** Stateful - maintains current framework state, error history, logs, and other context.

### 3.3 Bindings Library

**Location:** `libs/bindings`

**Purpose:** Shared ReScript bindings for Node.js APIs (fs, path, process, child_process, streams). Eliminates duplication across apps/libs.

## 4. Communication Architecture

### 4.1 Inter-Component Communication

**Agent Library ↔ Framework Middleware**: Direct function calls (in-process)

- **Protocol:** JavaScript/ReScript function calls
- **Format:** Native JavaScript objects/types
- **Direction:** Bidirectional via callbacks
- **Note:** May be refactored to STDIO/subprocess later for process isolation

**Framework Middleware ↔ UI**: WebSocket/HTTP

- **Protocol:** WebSocket for real-time updates, HTTP for commands
- **Format:** JSON
- **Direction:** Bidirectional

### 4.2 Communication Patterns

**Middleware → Agent:**
- Calls agent library functions with user requests and bundled context
- Provides callback functions for status updates
- Provides callback functions for context requests

**Agent → Middleware:**
- Returns response objects (success/failure, message, files changed)
- Invokes status update callbacks during processing
- Invokes context request callbacks when additional data needed
- Executes file operations directly via Node.js fs APIs

## 5. Data Flow

### 5.1 User Interaction Flow

1. User interacts with agent UI (embedded in their application)
2. UI communicates with framework middleware via WebSocket/HTTP
3. Framework middleware bundles relevant context with user request
4. Middleware calls agent library function with request + context + callbacks
5. Agent processes request using provided context, LLM, and tools
6. Agent may request additional context via callback functions
7. Middleware responds with requested context (callback returns data)
8. Agent invokes status callbacks during processing
9. Agent returns response object to middleware
10. Middleware forwards response to UI via WebSocket
11. User receives response

### 5.2 Context Management Flow

**Context Collection (Middleware):**
1. Framework emits events (compilation, logging, routing)
2. Middleware collectors capture and store events
3. Context remains in middleware memory
4. Context is passed to agent when calling library functions

**Context Retrieval (Agent):**
1. Agent receives request with initial context bundle
2. Agent determines if additional context is needed
3. Agent calls provided callback function for additional context
4. Middleware retrieves and returns requested context
5. Agent continues processing with full context

## 6. Technology Stack

### 6.1 Agent Library
- **Language:** ReScript
- **Runtime:** Node.js (in-process with framework)
- **Communication:** Direct function calls with callbacks
- **State:** Stateful (maintains conversation context)

### 6.2 Framework Integration
- **Language:** ReScript
- **Runtime:** Node.js (embedded in framework dev server)
- **UI Framework:** React
- **Communication:** WebSocket/HTTP (UI), Function calls (Agent)
- **State:** Stateful (maintains framework context)

## 7. Deployment Architecture

### 7.1 Package Structure

```
ask-the-llm/
├── libs/
│   ├── agent/              # Agent library (core logic)
│   ├── bindings/           # Shared Node.js bindings
│   └── nextjs/             # Next.js integration middleware
└── test/examples/
    └── blog-starter/       # Development/testing Next.js app
```

### 7.2 Installation Flow

1. Developer installs framework integration package (`npm install @ask-the-llm/nextjs`)
2. Developer configures framework to use middleware (one-line config change)
3. Developer starts their development server normally
4. Middleware initializes, creates agent library instance, injects UI
5. Agent becomes available for interaction

### 7.3 Development and Testing

The `test/examples/` directory contains framework applications used for development, testing, and demonstrating integration:

```
test/examples/
└── blog-starter/        # Next.js application with middleware integrated
    ├── src/             # Next.js app router
    ├── next.config.js   # Uses middleware
    └── package.json     # Depends on local middleware
```

**Purpose:**
- Rapid iteration during development
- Integration testing with real framework
- Reference implementation for users
- Documentation through working examples

**Development Workflow:**
1. Make changes to middleware or agent library code
2. Changes hot-reload in example app
3. Test integration in real environment
4. Validate before publishing

## 8. Context Strategy

### 8.1 Context Collection

The framework middleware continuously collects context from the running application:
- Compilation errors and warnings (captured when they occur)
- Runtime logs (buffered in memory)
- Route information (tracked on changes)
- Build status and performance metrics

### 8.2 Context Delivery

Context is delivered to the agent in two ways:

**Bundled with Request:** Common/relevant context is passed as parameters when calling agent library functions (recent errors, current route, etc.)

**On-Demand:** Agent requests specific context via callback functions when needed (full log history, specific file content, detailed error traces)

## 9. Extensibility

### 9.1 Framework Support

The architecture supports multiple frameworks through isolated integration packages. Each framework integration imports the same agent library and provides the required context and callbacks, ensuring consistency across platforms.

### 9.2 Tool System

The agent library maintains a registry of tools that can be executed. Tools follow a standardized interface for execution and result reporting.

## 10. Error Handling and Resilience

### 10.1 In-Process Design

The agent runs in-process with the framework for simplicity. While this means agent errors could potentially affect the dev server, it eliminates IPC overhead and complexity. May be refactored to a subprocess later for better isolation.

### 10.2 Recovery Mechanisms

- Agent errors are caught and handled gracefully by the middleware
- Middleware can recreate agent instance on critical failures
- Middleware maintains context state across agent instance recreation
- LLM failures implement retry logic with exponential backoff
- File operation conflicts are detected and reported

---

**Document Version:** 1.3
**Last Updated:** 2025-10-15
**Classification:** Internal Architecture Documentation

**Major Changes in v1.3:**
- Simplified from subprocess/STDIO architecture to in-process library with direct function calls
- Agent library now runs in same process as framework middleware
- Communication changed from JSON over STDIO to direct JavaScript/ReScript function calls with callbacks
- Reduced complexity and IPC overhead
- Note: May be refactored to subprocess later if process isolation becomes necessary
