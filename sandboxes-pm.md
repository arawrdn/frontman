# Frontman Cloud Sandboxes PM Brief

## Purpose

Frontman Cloud Sandboxes let Frontman users work with Frontman online instead of only against a local dev server. The product goal is to give each repo branch or GitHub issue a cloud-hosted development workspace where users can open the app preview, chat with Frontman, let the agent edit code, run the dev server, and push resulting work back through GitHub.

This document is intended for an outsourced engineering team. It explains what Frontman is today, how it currently works, the cloud sandbox product direction, and the major technical decisions already made.

## What Frontman Is

Frontman is a browser-based AI coding agent for frontend work. A user opens their running web app, gets a Frontman chat UI next to a live preview, clicks or describes what they want changed, and Frontman edits the actual source files in the existing codebase.

Frontman is strongest when visual context matters. Unlike IDE-only agents, it can inspect the rendered DOM, computed styles, screenshots, routes, framework metadata, and development server context. This lets it connect what the user sees in the browser to the source code that produced it.

Typical users are:

- Frontend developers making UI changes with live feedback.
- Designers and PMs making copy, layout, color, and spacing changes without opening an IDE.
- Teams that want visual frontend iteration to happen through the normal branch and PR workflow.

## How Frontman Works Today

Frontman currently has three main pieces.

1. Browser client

The browser client is a ReScript/React application embedded into the user's dev server. It renders:

- A chat interface.
- A live preview iframe of the user's app.
- Annotation and element-selection UI.
- Tool-call progress, plans, errors, and questions.

The client also executes browser-side tools for the agent, such as screenshots, DOM inspection, clicking, typing, navigation, text search, and device viewport changes.

2. Frontman server

The server is an Elixir/Phoenix application. It owns:

- Authentication and users.
- Task/session persistence.
- LLM provider and API key resolution.
- Agent orchestration through `SwarmAi.Runtime`.
- Tool-call routing.
- WebSocket channels.
- PostgreSQL persistence for conversation history and tool events.

The server does not currently have direct access to the user's project filesystem. That is intentional in the local architecture.

3. Framework integrations

Frontman ships npm packages for supported frameworks:

- `@frontman-ai/nextjs`
- `@frontman-ai/astro`
- `@frontman-ai/vite`

These integrations inject Frontman into the user's dev server. They serve the Frontman UI, expose project/file tools, capture framework context, and help resolve rendered UI back to source files.

## Current Communication Model

Frontman uses JSON-RPC over WebSockets with two application-level protocols.

ACP, Agent Client Protocol, handles conversation/session lifecycle:

- Create/load/delete sessions.
- Send prompts.
- Stream assistant responses.
- Send turn completion, errors, plans, and config updates.

MCP, Model Context Protocol, handles tools:

- Tool discovery.
- Tool execution.
- Tool results.

Today, file and project tools are relayed through the browser to the dev server:

```text
Agent on Frontman Server
  -> MCP tool call over WebSocket
  -> Browser client
  -> HTTP/SSE relay to user's dev server integration
  -> Filesystem/project operation
  -> Browser client
  -> Tool result back to Frontman Server
  -> Agent continues
```

This means local Frontman requires:

- The user's dev server to be running.
- The browser tab to stay connected for browser and relay tools.
- The framework integration to expose file/project tools.

## Current Server Domain Model

The important existing domain object is `Task`.

Today a task is a conversation session. It is not a cloud compute workspace.

The `tasks` table stores:

- `id`: client-provided UUID.
- `short_desc`: generated title.
- `framework`: Next.js, Astro, Vite, etc.
- `user_id`.

The `interactions` table stores typed JSONB events for a task:

- User messages.
- Agent responses.
- Tool calls.
- Tool results.
- Agent lifecycle events.
- Discovered project rules.
- Discovered project structure.

All interactions are persisted before being broadcast to clients. On reconnect, history is loaded from PostgreSQL and replayed.

## Why Cloud Sandboxes Are Needed

The current product assumes the user's machine is the compute environment. The user must clone the repo, install dependencies, start the dev server, expose Frontman through the framework integration, and keep the browser connected.

For Frontman to work online, Frontman needs to host the equivalent of the user's local development environment:

- Git repo checkout.
- Branch or issue-specific working state.
- Dependencies and build tools.
- Environment variables.
- Running dev server.
- Preview URL.
- Framework integration.
- File/project tools.
- GitHub commit/PR/issue side effects.

The key product shift is not simply moving the existing Frontman server to cloud compute. The server already runs in production. The new product primitive is a cloud-hosted development workspace/sandbox that replaces the user's local dev server environment.

## Product Direction

Add a first-class `Workspace` concept.

A workspace is a cloud-hosted development environment tied to a repo branch and optionally a GitHub issue. Many Frontman tasks can run against the same workspace and share the same project state.

Recommended mental model:

```text
Organization
  -> Repository
    -> Workspace
      -> Branch
      -> Optional GitHub issue
      -> Cloud compute sandbox
      -> Dev server and preview URL
      -> Environment config
      -> Many Frontman tasks/conversations
```

Tasks remain conversation history. Workspaces own project/runtime state.

## Decisions Already Made

### Workspace Model

Use a hybrid stateful model tied to git branches or issues.

Multiple Frontman tasks can operate on the same issue or branch and share the same workspace state. The state is not tied to a single LLM run.

### Isolation

Use containers backed by microVM-style isolation.

Frontman will run arbitrary customer code, package installs, tests, and dev servers. Tenant isolation must be stronger than plain shared containers.

Acceptable technologies could include Firecracker, Kata Containers, gVisor, or a provider that offers equivalent isolation. Exact provider/runtime is still open.

### Git Identity

Use a hybrid GitHub identity model.

Frontman should operate through a GitHub App/bot installation for repo access, with human user attribution in commits, comments, metadata, and audit logs.

### Tool Boundary

Use a hybrid tool execution model.

The cloud workspace should run the user's real dev server for preview, DOM, framework, route, and runtime context. But pure filesystem tools can move into a workspace sidecar instead of always relaying through the browser.

This means v1 should support:

- Real app preview through the framework integration.
- Browser tools still executed by the active browser client.
- File tools such as read, write, edit, grep, list, and tree executed by a trusted workspace sidecar when safe.

This preserves fidelity while reducing unnecessary browser relay dependence.

### Framework Integration Setup

Use auto-install in the workspace plus an optional setup PR.

For v1, Frontman should be able to temporarily patch/install the required framework integration inside the cloud checkout so the user can start quickly. This workspace mutation should not automatically become a permanent repo change unless Frontman creates or updates a PR.

After successful use, Frontman can offer or automatically create a setup PR that makes the integration durable in the repo.

### Secrets

Use minimal user-provided environment variables first.

Users should be able to configure env vars per repo/workspace. Frontman should detect missing env vars and report boot failures clearly. Do not build a full external secret manager integration in v1, but design the secret storage boundary so providers like 1Password, Doppler, Infisical, or Vault can be added later.

### Compute Platform

Use a hybrid bootstrap strategy.

Launch on a provider or thin managed substrate if it accelerates delivery, but define a `WorkspaceProvider` abstraction from day one so the system can later move hot workloads onto our own fleet.

Avoid baking assumptions about one vendor directly into Tasks, Channels, or product workflows.

### Start Object

Support GitHub issue or repo branch as the entry point.

The branch is the durable primitive. A GitHub issue can provide naming, context, branch creation, and PR automation.

### Background Execution

For v1, require an active browser session.

This keeps the product close to the existing architecture. Browser-side tools, visual inspection, and interactive question flows require a connected user tab.

Cloud v1 is therefore remote collaborative development, not fully autonomous background coding.

### Approval Gates

No approval gates for v1.

Frontman may edit files, run commands, install dependencies, push commits, open/update PRs, comment on issues, and expose workspace preview URLs without per-action confirmation.

Because this is high trust and high risk, compensating controls are required:

- Detailed audit logs.
- Easy rollback.
- Clear ownership attribution.
- Ability to disable or suspend a workspace.
- Internal kill switch for abuse or runaway behavior.

### Resource Limits

No hard user-facing resource limits initially.

This is acceptable only for controlled beta or limited rollout. Engineering should still implement internal observability and emergency controls for CPU, memory, disk, network, process count, and spend.

### Preview Access

Workspace preview/dev-server URLs are accessible only to workspace members.

Do not make previews public by default. Dev servers often expose debug information, environment-dependent behavior, and unauthenticated application states.

## Proposed Architecture

### New Core Services

1. Workspace API

Owns CRUD and lifecycle for workspaces:

- Create workspace from repo branch or issue.
- Start/stop/suspend workspace.
- Attach tasks to workspace.
- Store env config metadata.
- Store provider/runtime metadata.
- Expose workspace status and preview URLs.

2. Workspace Scheduler/Provider

Abstracts the underlying compute substrate:

- Provision sandbox.
- Clone repo.
- Checkout/create branch.
- Start sidecar.
- Start dev server.
- Report health/status.
- Suspend/destroy workspace.

The provider abstraction should allow multiple implementations:

- Managed sandbox provider.
- Our own node fleet.
- Local/dev provider for testing.

3. Workspace Sidecar

Runs inside the sandbox next to the repo checkout. Owns safe project-local operations:

- Read/write/edit files.
- Search files.
- Grep.
- List tree.
- Run package manager install.
- Run commands/tests if enabled.
- Detect framework and scripts.
- Report dev server health.

The sidecar should expose an internal authenticated API to the Frontman server or workspace gateway. It should not be publicly reachable.

4. Workspace Gateway/Proxy

Routes authenticated users to workspace services:

- Preview app URL.
- Frontman UI URL.
- Dev server websockets/HMR.
- Sidecar control plane if needed.

All access should require Frontman auth and workspace membership.

5. GitHub Integration

Uses GitHub App installation permissions to:

- List repos and branches.
- Read issues.
- Create branches.
- Push commits.
- Open/update PRs.
- Comment on issues.
- Attribute actions to the user in metadata.

## Data Model Additions

Exact schema can evolve, but the outsourced team should expect at least these concepts.

### repositories

Represents a connected GitHub repository.

Suggested fields:

- `id`
- `organization_id`
- `provider`: `github`
- `provider_repo_id`
- `owner`
- `name`
- `full_name`
- `default_branch`
- `installation_id`
- timestamps

### workspaces

Represents a cloud development environment.

Suggested fields:

- `id`
- `organization_id`
- `repository_id`
- `created_by_user_id`
- `branch_name`
- `base_branch`
- `github_issue_number`, nullable
- `github_pr_number`, nullable
- `status`: creating, installing, booting, running, unhealthy, suspended, failed, destroyed
- `framework`: nextjs, astro, vite, unknown
- `provider`: provider implementation name
- `provider_workspace_id`
- `preview_url`
- `frontman_url`
- `last_active_at`
- `failure_reason`
- timestamps

### workspace_env_vars

Stores encrypted environment variables scoped to a workspace or repo.

Suggested fields:

- `id`
- `workspace_id` or `repository_id`
- `key`
- `encrypted_value`
- timestamps

### task_workspace relationship

Current tasks should gain a nullable or required `workspace_id` once cloud mode is introduced.

For local mode, tasks may remain workspace-less or attach to a special local workspace representation.

## User Journey For V1

1. User signs in to Frontman Cloud.
2. User installs or authorizes the Frontman GitHub App.
3. User selects a repo and either an existing branch or a GitHub issue.
4. Frontman creates or finds a workspace for that branch/issue.
5. Frontman provisions isolated compute.
6. Workspace clones the repo and checks out or creates the branch.
7. Workspace detects framework and package manager.
8. Workspace installs dependencies.
9. Workspace temporarily installs/configures the Frontman framework integration if missing.
10. Workspace starts the dev server.
11. Frontman exposes an authenticated preview URL to workspace members.
12. User opens Frontman in the browser and starts a task.
13. The browser connects to the existing Frontman server over ACP/MCP.
14. Agent tools use browser context for visual operations and workspace sidecar for file operations where possible.
15. Frontman edits code in the workspace branch.
16. Frontman may push commits, open or update PRs, and comment on issues without confirmation in v1.

## Important Engineering Constraints

### Preserve Current Task Semantics

Do not overload `Task` to mean compute workspace. A task is conversation history. Add `Workspace` as a separate domain.

### Keep Local Frontman Working

Cloud sandboxes must not break the existing local dev-server architecture. Local users still rely on browser-to-dev-server relay.

### Keep Tooling Pluggable

Cloud introduces a new sidecar path for file tools. Avoid duplicating business logic unnecessarily. File tools should have common semantics whether executed through local framework integration or cloud sidecar.

### Auth Every Preview Request

Workspace URLs must be protected by Frontman auth and membership checks. HMR and websocket traffic must also work through this auth/proxy layer.

### Assume Arbitrary Code Is Hostile

Customer repos can run arbitrary install scripts, dev servers, and tests. The sandbox should not trust project code.

Minimum expectations:

- MicroVM-grade isolation.
- No cross-tenant filesystem sharing.
- Scoped credentials.
- Network controls where feasible.
- No direct access to Frontman production secrets.
- Strong cleanup on destroy.

### Audit Everything

Because v1 has no approval gates, Frontman must provide reliable audit trails for:

- Workspace creation/destruction.
- Commands run.
- Files changed.
- Commits pushed.
- PRs opened/updated.
- Issue comments.
- Env var changes.
- User/session responsible.

## MVP Scope

The smallest useful v1 should include:

- GitHub App installation and repo selection.
- Workspace creation from branch.
- Workspace creation from GitHub issue that maps to a branch.
- Isolated sandbox provisioning.
- Repo clone and branch checkout/create.
- Dependency install.
- Framework detection for Next.js, Astro, and Vite.
- Temporary Frontman integration install if missing.
- Dev server start with preview URL.
- Authenticated preview access for workspace members.
- Existing Frontman chat/task flow attached to workspace.
- Workspace sidecar for read/write/edit/list/grep/tree file tools.
- Commit push and PR create/update through GitHub App.
- Basic encrypted env var entry.
- Workspace status UI: creating, installing, booting, running, failed.
- Failure logs visible to user.
- Internal admin kill switch.

## Explicit Non-Goals For V1

- Fully autonomous background agents after browser tab close.
- Public preview links.
- Enterprise secret-manager integrations.
- Complex billing tiers or hard public quotas.
- Multi-cloud scheduler sophistication.
- Supporting every framework/package manager edge case.
- Merge/deploy automation unless already trivial through GitHub flow.

## Open Engineering Questions

These remain for implementation discovery:

- Which sandbox provider/runtime gives the best v1 speed while preserving a future path to our own fleet?
- How exactly should temporary integration install work for each framework without polluting user diffs?
- Should the sidecar speak MCP directly, or should the Frontman server adapt sidecar APIs into existing tool calls?
- How do we proxy authenticated HMR/websocket traffic cleanly for Next.js, Vite, and Astro?
- What is the minimum env-var UX needed to diagnose failed boots?
- How do we represent local workspaces versus cloud workspaces in the product without confusing existing users?
- What command execution surface is needed beyond install/dev/test?
- How do we make no-approval external GitHub side effects safe enough with audit and rollback?

## Suggested Delivery Phases

### Phase 1: Architecture Spike

- Build local/dev `WorkspaceProvider` that provisions workspaces on the current machine or existing worktree system.
- Define `Workspace` schema and lifecycle state machine.
- Attach tasks to workspaces.
- Prove sidecar file tools can replace browser-relayed file tools for cloud mode.

### Phase 2: Hosted Sandbox Prototype

- Pick a sandbox provider for prototype.
- Provision isolated workspace from GitHub repo/branch.
- Start dev server and expose authenticated preview.
- Connect existing Frontman UI to the hosted preview.

### Phase 3: GitHub Workflow

- Add GitHub App installation flow.
- Create branch from issue.
- Push commits from workspace.
- Open/update PR.
- Add audit events for external side effects.

### Phase 4: Reliability And Beta

- Add boot diagnostics.
- Add env var management.
- Add admin kill switch.
- Add spend/resource observability.
- Run controlled beta with no public hard limits.

## Success Criteria

V1 is successful when a user can:

- Sign in online.
- Pick a GitHub repo and branch or issue.
- Wait for Frontman to boot a cloud workspace.
- Open a live preview of the app in the browser.
- Ask Frontman to make a visual/code change.
- See the app hot reload or restart with the change.
- Have Frontman commit/push/open a PR without using a local dev environment.

The user should not need to clone the repo locally, run package installs locally, or start the dev server locally.
