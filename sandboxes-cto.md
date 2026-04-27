# Frontman Cloud Sandboxes CTO Handoff

## Purpose

This document turns the Cloud Sandboxes PM brief into an execution-oriented CTO handoff for an engineer with limited prior context.

Read this together with `sandboxes-pm.md`. The PM brief explains the long-term product direction. This document defines the narrow internal dogfood version we actually want to build first.

The goal is not to build a generic cloud IDE, a sandboxing company, or a full enterprise product. The goal is to prove that Frontman can run online against its own repo, edit code in a cloud workspace, show a live preview, and push the result back to GitHub.

## Final V1 Dogfood Scope

Build Frontman Cloud Dogfood for the `frontman` repo only.

The first successful user journey is:

1. An internal user signs into Frontman Cloud.
2. The user selects an existing branch in the `frontman` GitHub repo.
3. Frontman creates or reuses a cloud workspace for that branch.
4. The workspace boots the full Frontman development stack.
5. The user opens the authenticated preview in a browser.
6. The user starts a Frontman task attached to that workspace.
7. Frontman uses browser tools for visual context and workspace sidecar tools for file operations.
8. Frontman edits files in the cloud checkout.
9. At task completion, Frontman commits and pushes changes back to the same branch.

If we can do this reliably enough for daily internal use, v1 is successful.

## Stakeholder Decisions Already Made

These decisions are not open unless the stakeholder explicitly reopens them.

- Audience: internal dogfood only.
- Repo scope: only the `frontman` repo initially.
- Start object: existing GitHub branch.
- Do not support GitHub issue start flow in v1.
- Do not support arbitrary repos in v1.
- Runtime target: full Frontman app stack, not a partial preview-only mode.
- Compute strategy: use a managed compute/sandbox provider if possible.
- Provider priority: fastest path to working dogfood plus low cost.
- Provider lock-in tolerance: moderate.
- Durability boundary: GitHub branch, not persistent workspace disk.
- Push behavior: automatically push at task completion.
- Secrets strategy: defer final decision until provider evaluation. Prefer the simplest provider-supported approach that gets internal dogfood working.
- Launch bar: daily internal use without constant babysitting.

## CTO Interpretation

This project should be treated as a narrow product proof, not a platform rewrite.

The smallest useful v1 is:

> Open an existing `frontman` branch in the browser, boot the full Frontman stack in managed compute, use Frontman against itself, and push changes back when the task finishes.

Do not generalize early. Every extra repo, framework, provider, GitHub workflow, approval gate, or secret manager integration increases delivery risk. The dogfood goal is to prove the loop before scaling the surface area.

## Important Context About Frontman

Frontman is a browser-based AI coding agent for frontend work.

It currently has three main pieces:

- Browser client: ReScript/React UI embedded into the user's dev server. It provides chat, live preview, annotation UI, browser-side tools, screenshots, DOM inspection, clicking, typing, navigation, and viewport changes.
- Frontman server: Elixir/Phoenix app that owns auth, users, task/session persistence, LLM provider resolution, agent orchestration, WebSocket channels, and PostgreSQL persistence.
- Framework integrations: npm packages for Next.js, Astro, and Vite. These inject Frontman into the user's dev server and expose project/file/framework tools.

Today, the server does not directly access the user's filesystem. Local file tools are relayed through the browser to the local dev server integration.

Current local flow:

```text
Agent on Frontman Server
  -> MCP tool call over WebSocket
  -> Browser client
  -> HTTP/SSE relay to user's local dev server integration
  -> Filesystem/project operation
  -> Browser client
  -> Tool result back to Frontman Server
  -> Agent continues
```

Cloud workspaces add a new compute environment that replaces the user's local dev server. Browser tools still matter for visual context, but safe file operations can move into a sidecar running inside the cloud workspace.

## Product Model To Preserve

Do not overload `Task` to mean cloud compute.

Use separate concepts:

- `Task`: conversation/session history.
- `Workspace`: cloud development environment tied to a repo branch.
- `Repository`: connected GitHub repo metadata. For dogfood, this can initially be allowlisted/hardcoded to `frontman` but should still be modeled cleanly.

Mental model:

```text
Organization
  -> Repository
    -> Workspace
      -> Branch
      -> Managed compute sandbox
      -> Dev server and preview URL
      -> Environment config
      -> Many Frontman tasks/conversations
```

Tasks attach to workspaces. Workspaces own runtime/project state.

## Non-Goals For Dogfood V1

Do not build these unless explicitly asked:

- Generic repo onboarding.
- Any GitHub repo support.
- GitHub issue start flow.
- Automatic PR creation.
- Public preview links.
- Enterprise secret-manager integrations.
- Billing, user-facing quotas, or pricing logic.
- In-house microVM/sandbox infrastructure.
- Multi-provider scheduling sophistication.
- Fully autonomous background agents after browser tab close.
- Approval gates for every action.
- Complex setup PR flow.
- Support for every package manager or framework edge case.

These are valid future features, but building them now will slow down the only outcome that matters: daily internal dogfood.

## Provider Strategy

We are not a sandboxing company. Do not build sandbox isolation in-house for v1.

Use a managed provider if it can satisfy the dogfood loop. Keep provider usage behind a thin `WorkspaceProvider` interface so we avoid baking provider-specific assumptions into Tasks, Channels, or product workflows.

Provider dependency level should be moderate:

- It is acceptable to use provider-native sandbox creation, logs, start/stop, and suspend/resume if helpful.
- Frontman should still own workspace records, task attachment, Git push policy, preview auth, sidecar tool semantics, and audit events.
- If the provider fails or becomes too expensive, migration should hurt but not require a product rewrite.

Provider categories to evaluate:

- Managed devbox/sandbox providers such as Daytona, E2B, Modal sandboxes, or similar.
- Managed container/runtime platforms such as Fly Machines, Railway, Render, Northflank, or similar.
- Dedicated host with the existing Podman worktree flow only as a fallback if managed providers cannot boot the full stack or proxy preview/HMR correctly.

Provider selection criteria, ordered by importance:

1. Fastest path to working dogfood.
2. Low enough cost for daily internal use.
3. Can run the full `frontman` development stack.
4. Can expose preview plus WebSocket/HMR traffic cleanly.
5. Provides retrievable boot/runtime logs.
6. Provides workable environment variable/secrets injection.
7. Provides an API for create/start/stop/destroy/status.
8. Does not force product architecture into a dead end.

## Required Provider Spike

Before building broad application architecture, run a provider spike.

The provider spike should answer one question:

> Can this provider boot the full `frontman` stack from an existing branch, expose a usable preview, provide logs, support needed secrets, and do so cheaply enough for daily dogfood?

Minimum spike steps per provider:

1. Create sandbox/runtime from API or CLI.
2. Clone the `frontman` repo.
3. Checkout an existing branch.
4. Install dependencies.
5. Start the full Frontman dev stack.
6. Expose the preview URL.
7. Verify preview is usable in browser.
8. Verify HMR/WebSocket traffic works or identify exact blockers.
9. Retrieve boot and runtime logs.
10. Inject required environment variables by the simplest provider-supported mechanism.
11. Commit and push a trivial change back to the same branch using a bot/GitHub credential.
12. Destroy the sandbox.
13. Estimate cost per active daily workspace.

Spike exit criteria:

- One existing branch can boot reliably.
- Preview is reachable and usable.
- Logs are available to Frontman or can be made available.
- Workspace can be destroyed and recreated.
- Secrets/env var path is understood well enough to proceed.
- Git push path is understood well enough to proceed.
- Cost is acceptable for internal daily use.

If no managed provider can satisfy this quickly, propose the fallback explicitly before building custom infrastructure.

## Proposed Runtime Architecture

Dogfood architecture:

```text
Frontman Server
  -> Workspace API
  -> WorkspaceProvider
    -> Managed sandbox/runtime
      -> frontman repo checkout
      -> full Frontman dev stack
      -> workspace sidecar
      -> dev server / preview

Browser
  -> authenticated Frontman Cloud UI
  -> authenticated workspace preview
  -> ACP/MCP WebSocket connection to Frontman server

Agent
  -> browser tools for visual context
  -> workspace sidecar tools for file operations
  -> GitHub commit/push on task completion
```

The active browser session is required in dogfood v1. This is remote collaborative development, not background autonomous coding.

## WorkspaceProvider Interface

Create a provider abstraction from day one, but keep it thin.

Suggested provider operations:

- `create_workspace(repository, branch, env)`
- `start_workspace(workspace)`
- `stop_workspace(workspace)`
- `destroy_workspace(workspace)`
- `get_workspace_status(workspace)`
- `get_workspace_logs(workspace)`
- `get_preview_url(workspace)`
- `get_sidecar_endpoint(workspace)`

The provider should return provider-specific IDs and URLs, but the rest of the app should use Frontman `Workspace` records as the source of truth.

Do not let provider-specific concepts leak into task/session logic.

## Workspace Lifecycle

Suggested statuses:

- `creating`
- `booting`
- `running`
- `failed`
- `destroyed`

Optional later statuses:

- `installing`
- `unhealthy`
- `suspended`

For dogfood, keep the lifecycle simple. Better to have fewer states with good logs than many states no one trusts.

Required lifecycle behavior:

- Creating a workspace starts provider provisioning.
- Booting includes clone, checkout, install, and dev server start.
- Running means preview and sidecar are reachable.
- Failed must include a visible failure reason and logs.
- Destroyed must clean up provider resources.
- Recreate from branch must be possible because Git is the durability boundary.

## Data Model Additions

Exact schema should follow the repo's existing Elixir/Phoenix conventions, but expect these concepts.

### repositories

Represents a connected GitHub repository.

For dogfood this can be seeded or allowlisted to `frontman`, but do not put branch/runtime state here.

Suggested fields:

- `id`
- `organization_id`
- `provider`: initially `github`
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
- `base_branch`, nullable for existing-branch dogfood if unnecessary
- `status`
- `framework`, likely `unknown` or `frontman`-specific initially
- `provider`
- `provider_workspace_id`
- `preview_url`
- `frontman_url`, if separate from preview
- `sidecar_url` or internal endpoint reference
- `last_active_at`
- `last_pushed_commit_sha`
- `failure_reason`
- timestamps

### task workspace relationship

Current tasks should gain `workspace_id`, nullable if local mode still creates tasks without a cloud workspace.

Do not break local Frontman tasks.

### workspace audit events

Because dogfood v1 has automatic push at task completion and no per-action approvals, log important actions.

Suggested fields:

- `id`
- `workspace_id`
- `task_id`, nullable
- `user_id`, nullable for system events
- `event_type`
- `metadata` JSONB
- timestamps

Minimum events:

- workspace created
- workspace boot started
- workspace boot failed
- workspace running
- workspace destroyed
- command run
- files changed summary
- commit created
- push succeeded
- push failed
- env config changed
- kill switch used

## Workspace Sidecar

The sidecar runs inside the sandbox next to the checked-out repo.

It owns project-local operations that do not require browser visual context.

Minimum dogfood sidecar tools:

- read file
- write file
- edit file
- list directory
- tree
- grep/search
- git status
- git diff
- command execution for explicitly allowed commands only

Keep command execution narrow for dogfood. Everything must be logged.

The sidecar should not be publicly reachable. It should expose an internal authenticated API to Frontman server or through the provider's private network/control channel.

Recommended approach:

- Frontman server adapts sidecar operations into existing MCP tool semantics.
- Do not make the sidecar speak MCP directly unless that is clearly simpler in the current codebase.
- Keep local browser-relayed file tools working unchanged.
- Route file tools to sidecar only for cloud workspace tasks.

## Browser Tools Versus Sidecar Tools

Use hybrid tool execution.

Browser tools remain browser-side:

- screenshot
- DOM inspection
- computed styles
- clicking
- typing
- navigation
- viewport/device changes
- visual context collection

Sidecar tools run in the workspace:

- read/write/edit files
- grep/search/list/tree
- git diff/status
- controlled command execution

Do not remove the existing local browser-to-dev-server relay. Local Frontman must continue working.

## Preview And Auth

Workspace previews must not be public by default, even for dogfood.

Minimum expectation:

- Preview URL requires Frontman auth.
- User must be a workspace member or internal authorized user.
- Dev server WebSockets/HMR must work through the proxy or provider routing.
- If HMR cannot be made to work quickly, document the exact limitation and provide a manual reload fallback for dogfood only.

Preview/HMR routing is a major technical risk. Pick the provider partly based on how easy this is.

## GitHub Integration

Dogfood v1 uses existing branches only.

Required behavior:

- Clone `frontman` repo.
- Checkout selected existing branch.
- At task completion, create a commit from workspace changes.
- Push commit to the same branch.
- Store last pushed commit SHA on the workspace.
- Create audit events for commit and push.
- Surface push failures clearly in UI.

Do not build PR creation for dogfood v1 unless it is trivial after push works.

Commit attribution:

- Use GitHub App/bot credentials or another internal bot credential.
- Include human user attribution in commit message metadata if possible.
- Keep implementation simple for dogfood. Perfect enterprise attribution is not required yet.

Suggested commit message format:

```text
Update from Frontman cloud task

Task: <task id or title>
Workspace: <workspace id>
User: <user email or id>
```

## Secrets And Environment Variables

Final decision is deferred until provider evaluation.

For dogfood, choose the fastest safe-enough path the provider supports.

Options to evaluate:

- Provider-managed environment variables.
- Existing 1Password `op://` references if `op` can run cleanly inside the workspace.
- Frontman repo-level encrypted env config.
- Dogfood-only provider config outside the repo.

Do not build a general external secret-manager integration in v1.

Minimum requirement:

- The full Frontman stack can boot.
- Missing env vars produce clear boot failure logs.
- Secrets are not committed to the repo.
- Secrets are not exposed in preview URLs or regular user-visible logs.

## Full Frontman Stack Boot

The stakeholder selected full app stack as the boot target.

The engineer must inspect the existing repo's Makefiles and worktree/container workflow before deciding the exact boot command. This repo already has containerized worktree support using `make wt-*` and Podman. That may or may not be portable to the chosen provider.

Preferred order:

1. Reuse existing repo-supported development commands if they run cleanly in the provider.
2. If the existing worktree flow is too local/Podman-specific, create one explicit dogfood-only cloud boot script for `frontman`.
3. Do not build generic framework autodetection for dogfood unless it is already available and cheap to reuse.

The cloud boot path should be explicit and debuggable. Avoid magic.

## UI Requirements For Dogfood

Keep UI minimal.

Required internal UI:

- Select existing `frontman` branch.
- Create workspace.
- See workspace status.
- Open preview.
- See boot logs on failure.
- Restart workspace.
- Destroy workspace.
- See last pushed commit.
- See push failure if task completion push fails.

Nice-to-have but not required:

- Workspace list filtering.
- Fancy logs UI.
- Branch creation.
- PR creation.
- Cost display.

## Internal Controls

Even for dogfood, add basic controls because arbitrary code runs in the workspace.

Required:

- Admin kill switch to destroy/suspend a workspace.
- Cleanup job for stale workspaces.
- Basic resource/spend visibility from provider if available.
- Audit events for destructive and external side-effect actions.

Do not build a full quota/billing system.

## Delivery Phases

### Phase 0: Provider Spike

Goal: choose the provider and prove the full-stack boot loop.

Deliverables:

- Provider comparison notes.
- One working provider path.
- Boot logs.
- Preview URL proof.
- HMR/WebSocket assessment.
- Secrets/env var recommendation.
- Git push proof.
- Rough cost estimate.

Do not spend weeks polishing code before this is proven.

### Phase 1: Workspace Skeleton

Goal: add the domain model without changing local mode.

Deliverables:

- `repositories` model or equivalent allowlisted repo representation.
- `workspaces` model.
- `tasks.workspace_id` support.
- Basic lifecycle states.
- Thin `WorkspaceProvider` interface.
- One provider implementation.
- Internal create/status UI.

### Phase 2: Sidecar File Tools

Goal: execute cloud file operations inside the workspace.

Deliverables:

- Sidecar process/API in workspace.
- Read/write/edit/list/tree/grep tools.
- Git diff/status tools.
- Tool routing based on task workspace.
- Local mode remains unchanged.

### Phase 3: Preview + Frontman Loop

Goal: make Frontman usable against the hosted workspace.

Deliverables:

- Authenticated preview access.
- HMR/WebSocket support or documented dogfood fallback.
- Browser visual tools working against hosted preview.
- Task creation attached to workspace.
- Agent can edit files through sidecar and observe changes in preview.

### Phase 4: Auto-Push At Task Completion

Goal: make GitHub the durability boundary.

Deliverables:

- Detect changed files at task completion.
- Commit changes.
- Push to same branch.
- Store last pushed commit SHA.
- Audit commit/push events.
- Surface push failures.

### Phase 5: Daily Dogfood Hardening

Goal: make this usable internally without babysitting every run.

Deliverables:

- Boot failure logs visible in UI.
- Restart/destroy/recreate workspace.
- Stale workspace cleanup.
- Admin kill switch.
- Basic provider cost/resource observability.
- Clear unpushed/pushed state.

## Main Risks

### Full Stack Boot Risk

The `frontman` stack may be difficult to run in a managed sandbox.

Mitigation: run provider spike first. Do not build product UI before proving boot.

### Preview/HMR Risk

Dev server WebSockets and HMR through an authenticated proxy may consume significant time.

Mitigation: evaluate during provider spike. Prefer providers that make long-running HTTP/WebSocket services easy.

### Secrets Risk

Missing or awkward secrets can block boot.

Mitigation: include env var injection in provider spike. Keep dogfood approach simple.

### Git Push Risk

Automatic push at task completion can push broken code.

Mitigation: acceptable for dogfood. Use clear commit messages, audit events, and easy revert. Do not add approval gates yet.

### Scope Creep Risk

The obvious temptation is to build general cloud sandboxes.

Mitigation: only `frontman`, only existing branches, only internal users, only push same branch.

### Provider Lock-In Risk

Fast providers may have proprietary APIs.

Mitigation: moderate lock-in is acceptable. Keep provider details behind `WorkspaceProvider` and keep Frontman-owned concepts in our database.

## Definition Of Done For Dogfood V1

Dogfood v1 is done when an internal user can:

1. Select an existing branch in the `frontman` repo.
2. Create a cloud workspace.
3. Wait for the full Frontman stack to boot.
4. Open an authenticated preview.
5. Start a Frontman task attached to that workspace.
6. Ask Frontman to make a visual/code change.
7. See the change reflected in the hosted preview.
8. Finish the task.
9. See Frontman commit and push the change to the same branch.
10. Destroy or recreate the workspace if needed.

Daily internal use means this should work repeatedly without an engineer manually SSHing into the runtime every time.

## Engineer Operating Instructions

- Start by reading `sandboxes-pm.md` and this file.
- Do the provider spike before broad application changes.
- Keep changes minimal and dogfood-scoped.
- Preserve existing local Frontman behavior.
- Do not turn `Task` into a workspace.
- Do not build generic repo support yet.
- Do not build sandbox infrastructure in-house unless managed providers fail and the stakeholder approves the fallback.
- Log commands, pushes, and destructive actions.
- Make failures visible in the UI with logs, not hidden in provider dashboards only.
- When uncertain, prefer the path that gets `frontman` dogfood working sooner with less custom infrastructure.

## Open Questions For The Engineer To Resolve During Spike

These are implementation discovery questions, not stakeholder product questions.

- Which provider can boot the full `frontman` stack fastest and cheapest?
- What is the exact boot command or boot script for `frontman` in that provider?
- How will preview HTTP and HMR/WebSocket traffic be routed and authenticated?
- How will required environment variables be injected?
- How will the sidecar be packaged and started in the workspace?
- How will the Frontman server securely call the sidecar?
- What GitHub credential path is simplest for internal same-branch push?
- What logs can the provider expose through API, and what logs must the sidecar collect itself?
- What is the cleanup/destroy behavior, and how do we verify resources are actually gone?

## Recommended First Week Plan

Day 1:

- Read repo docs, `sandboxes-pm.md`, and this handoff.
- Inspect existing Makefiles and worktree/container workflow.
- Select 2-3 provider candidates.

Day 2-3:

- Run provider spike against the `frontman` repo.
- Attempt full-stack boot, preview, logs, env vars, and Git push.
- Record blockers precisely.

Day 4:

- Recommend one provider or explain why fallback is required.
- Draft the minimal `WorkspaceProvider` shape based on the winning provider.

Day 5:

- Start Phase 1 only after provider path is proven.
- Add the smallest workspace schema and internal status/create path.

If the provider spike fails, stop and report. Do not bury the failure under framework code.

## Technical Discovery Checklist By Phase

This section is the execution checklist. Each phase has technical questions to answer, experiments or implementation tasks, required artifacts, exit criteria, and escalation triggers.

Do not skip the questions. The goal is to expose hard blockers early instead of discovering them after billing a week of implementation time.

### Phase 0: Provider Spike Checklist

Purpose: prove or disprove that a managed provider can run the full `frontman` dogfood loop.

Technical questions to answer:

- Which provider is the fastest path to a working full-stack `frontman` workspace?
- What is the lowest-cost provider that still supports long-running dev servers and usable logs?
- Can the provider clone a private GitHub repo from API-created workspace startup?
- Can it checkout an existing branch reliably?
- What exact command sequence installs dependencies and boots the full Frontman stack?
- Which services and ports does the full stack require?
- Does the provider support multiple exposed ports if needed?
- Does preview HTTP work from a browser?
- Does HMR/WebSocket traffic work through the provider routing layer?
- Does the provider require sticky sessions, custom domains, or special WebSocket configuration?
- Can the provider expose logs through API, SDK, CLI, or file streaming?
- Can the provider inject environment variables without writing secrets to the repo?
- Can the provider run 1Password CLI if that becomes the chosen secrets path?
- Can the provider support a private sidecar endpoint reachable by the Frontman server?
- If not, can the sidecar connect outbound to Frontman instead?
- Can the workspace commit and push to the existing GitHub branch?
- What credentials are needed for clone and push?
- How is workspace destroy verified?
- What resources remain after destroy, if any?
- What is the rough cost per active workspace-hour and per idle workspace-day?
- What are provider limits that could block daily dogfood, such as CPU, memory, disk, process count, runtime duration, network egress, or sleeping behavior?

Experiments to run:

- Create a sandbox from provider API or CLI.
- Clone the `frontman` repo.
- Checkout a real existing branch.
- Install dependencies using the repo-supported path or a documented temporary boot script.
- Boot the full stack.
- Open the preview URL in a browser.
- Verify HMR or document exact reload limitations.
- Capture logs from a successful boot.
- Capture logs from an intentional failed boot.
- Inject one required env var using the provider mechanism.
- Make a trivial file change, commit it, and push to the same branch.
- Destroy the workspace and verify it is gone from provider UI/API.

Required artifact:

- A provider spike report committed or shared as a markdown file.
- Include provider name, setup steps, exact commands, exposed ports, preview URL shape, HMR result, logs access method, env var method, Git push method, destroy behavior, estimated cost, blockers, and recommendation.

Exit criteria:

- One provider can boot the full stack from an existing `frontman` branch.
- Preview is reachable by browser.
- Logs are retrievable.
- Env var injection has a plausible path.
- Git push has a plausible path.
- Workspace destroy works.
- Cost is acceptable for internal daily use.

Escalate before proceeding if:

- No provider can boot the full stack within the spike window.
- HMR/WebSockets appear impossible without major custom proxy work.
- Secrets cannot be injected safely enough for dogfood.
- Provider cost is obviously too high for daily use.
- Provider requires architecture that would bypass Frontman's `Workspace` model entirely.
- The only viable path is building our own sandbox infrastructure.

### Phase 1: Workspace Domain And API Checklist

Purpose: add the minimal Frontman-owned workspace model without breaking local mode.

Technical questions to answer:

- Where do existing `Task` records live in the Phoenix app, and what is the smallest safe migration to attach `workspace_id`?
- Should `workspace_id` be nullable for local tasks? Default answer: yes.
- What existing organization/user/repo models already exist and should be reused?
- Is a full `repositories` table needed immediately, or can `frontman` be seeded/allowlisted while preserving the future schema?
- What are the exact workspace lifecycle states for dogfood?
- Which process owns async workspace creation and boot status updates?
- Does the app already have background jobs, supervisors, or Oban-like infrastructure to use?
- How should provider errors be stored so they are visible in UI?
- What provider metadata must be stored to operate start/stop/destroy?
- How is workspace membership checked for internal dogfood?
- How will local-mode tasks behave when no workspace exists?

Implementation tasks:

- Add workspace schema/migration.
- Add nullable task-to-workspace relationship.
- Add audit event schema if not already available.
- Add `WorkspaceProvider` behaviour/interface.
- Add the first provider implementation behind that interface.
- Add internal-only create workspace action for `frontman` existing branches.
- Add workspace status endpoint/channel updates.
- Add basic internal UI for create/status/open preview.

Required artifact:

- Short implementation note listing new tables, lifecycle states, provider callbacks, and how local mode remains unchanged.

Exit criteria:

- An internal user can create a `frontman` branch workspace record.
- Provider provisioning starts from Frontman code, not only manual CLI.
- Workspace status changes are persisted.
- Failed workspace creation stores a failure reason.
- Existing local tasks still work.

Escalate before proceeding if:

- Attaching `workspace_id` risks breaking local task history or reconnect behavior.
- Existing auth/org model is unclear enough that workspace membership would be guessed.
- Provider lifecycle requires long-running calls that do not fit current server/job architecture.
- Workspace status cannot be updated reliably after async provider operations.

### Phase 2: Sidecar Tools Checklist

Purpose: run file/project tools inside the cloud workspace while preserving local tool behavior.

Technical questions to answer:

- What existing file tool names and schemas does Frontman expose over MCP today?
- Which local file tools must have identical semantics in cloud mode?
- Is there reusable tool implementation logic in the framework integrations, or must sidecar implement parallel behavior?
- Should the sidecar be written in Elixir, Node, ReScript-compiled JS, or another small runtime? Prefer the simplest runtime that fits deployment.
- How is the sidecar started during workspace boot?
- How does the Frontman server discover the sidecar endpoint?
- Is the sidecar reachable inbound from Frontman, or should it establish an outbound connection?
- What authentication protects sidecar calls?
- How is the sidecar auth token generated, stored, rotated, and revoked?
- What filesystem root is allowed?
- How does the sidecar prevent path traversal outside the repo checkout?
- What file size limits are needed for read/write/grep responses?
- What commands are allowed in dogfood v1?
- How are command stdout/stderr and exit codes captured?
- How are command timeouts enforced?
- How are sidecar tool calls audited?

Minimum sidecar API/tool operations:

- Read file.
- Write file.
- Edit file.
- List directory.
- Tree.
- Grep/search.
- Git status.
- Git diff.
- Run explicitly allowed command with timeout.

Initial allowed commands should be narrow and explicit, for example:

- Git status/diff-related commands.
- Package install command if needed by boot flow.
- Project test/build commands only if already required by the agent flow.

Required artifact:

- Sidecar API contract with request/response examples.
- Tool routing note explaining when cloud tasks use sidecar and when local tasks use existing relay.
- Security note covering auth, repo root restriction, command allowlist, and logging.

Exit criteria:

- Cloud task can read, edit, and diff files through the sidecar.
- Existing local file tools still work.
- Tool failures return clear errors to the agent/user.
- Sidecar cannot read outside the repo root in basic path traversal tests.
- Sidecar calls are logged or audited.

Escalate before proceeding if:

- Existing MCP tool schemas are ambiguous or undocumented.
- Sidecar networking requires exposing an unauthenticated public endpoint.
- Path traversal or command execution cannot be restricted quickly.
- Tool routing would require a large rewrite of ACP/MCP channels.

### Phase 3: Preview, Auth, And HMR Checklist

Purpose: make the hosted app preview usable through Frontman Cloud.

Technical questions to answer:

- What URL should the user open for a workspace?
- Is the Frontman UI served separately from the app preview or injected into the hosted dev server?
- How does the authenticated preview proxy verify the current user can access the workspace?
- Does preview routing happen in the Frontman Phoenix app, provider routing layer, or a separate gateway?
- How are cookies/headers handled between Frontman auth and the proxied dev server?
- Does the target dev server use absolute URLs that need rewriting?
- Which WebSocket paths are needed for HMR, Phoenix channels, Vite, Next.js, or other dev services?
- Does the provider support WebSocket proxying directly?
- Is sticky routing required for WebSockets?
- How are multiple exposed services mapped to one workspace URL?
- How are preview URLs invalidated when a workspace is destroyed?
- What happens if the dev server crashes after workspace status is `running`?
- How is health checked?

Experiments/tasks:

- Proxy normal HTTP preview traffic through authenticated access.
- Proxy or route WebSocket/HMR traffic.
- Open preview in browser and verify hot reload if available.
- Kill the dev server and verify health/status changes or failure is visible.
- Destroy workspace and verify preview URL stops working.

Required artifact:

- Preview routing design note with URL structure, auth check, WebSocket/HMR behavior, and known limitations.

Exit criteria:

- Authenticated internal user can open workspace preview.
- Unauthorized user cannot open workspace preview.
- Browser-side Frontman tools can operate against the hosted preview.
- HMR works, or a documented manual reload fallback is accepted for dogfood.
- Destroyed workspace preview is inaccessible.

Escalate before proceeding if:

- Preview must be public to work.
- WebSocket proxying requires a major infrastructure rewrite.
- Frontman UI cannot connect cleanly to the hosted preview.
- Provider URL/routing model prevents authenticated access control.

### Phase 4: Auto-Push At Task Completion Checklist

Purpose: make GitHub the durability boundary by pushing changes when a task completes.

Technical questions to answer:

- Where in the existing ACP/task lifecycle is task completion detected?
- Is there exactly one reliable completion event, or multiple possible terminal states?
- Should push happen after successful assistant completion only, or also after interrupted tasks with file changes?
- How are changed files detected?
- How are generated/cache files excluded?
- What files must never be committed, such as `.env`, secrets, provider tokens, logs, dependency caches, or local DB files?
- Should formatting/tests run before commit? Default for dogfood: no unless already cheap and reliable.
- What happens if there are no changes at task completion?
- What happens if the remote branch has advanced and push is rejected?
- Should the system pull/rebase automatically? Default for dogfood: no, surface push failure clearly.
- What Git author and committer identity should be used?
- How is human attribution included?
- How are commit and push failures surfaced to the user?
- Can the user manually retry push?
- How is `last_pushed_commit_sha` stored and displayed?

Implementation tasks:

- Add task-completion hook for cloud workspace tasks.
- Ask sidecar for git status/diff.
- Refuse to commit obvious secret/env files.
- Create commit with standard message.
- Push to same branch.
- Store commit SHA.
- Add audit events for commit attempted, commit created, push succeeded, push failed.
- Show push status in workspace/task UI.

Required artifact:

- Git push behavior note covering completion trigger, ignored files, conflict behavior, attribution, and retry behavior.

Exit criteria:

- A completed cloud task with file changes creates and pushes a commit.
- A completed cloud task with no changes does not create an empty commit.
- Push failure is visible and does not mark workspace as successfully durable.
- Secret-like files are not committed in basic tests.
- Last pushed commit is visible.

Escalate before proceeding if:

- Task completion is not reliably detectable.
- Push requires broad user OAuth permissions instead of a scoped app/bot path.
- Remote branch conflict behavior is unclear and could overwrite user work.
- Generated files or secrets are likely to be committed accidentally.

### Phase 5: Daily Dogfood Reliability Checklist

Purpose: make the system usable internally without constant engineer babysitting.

Technical questions to answer:

- What are the top 5 expected failure modes from the spike and early implementation?
- Which logs should be visible to regular internal users?
- Which logs should be admin-only because they may contain secrets?
- How does a user restart a failed workspace?
- How does a user destroy and recreate from branch?
- How does an admin kill a runaway workspace?
- How are stale workspaces detected?
- What TTL should apply to inactive workspaces during dogfood?
- Does provider billing continue while workspace is idle/suspended?
- How do we detect provider resources that failed to destroy?
- What metrics are needed to understand cost and reliability?
- What alert, dashboard, or manual report is enough for dogfood?
- What is the support playbook when boot fails?

Implementation tasks:

- Add visible boot logs.
- Add restart action.
- Add destroy action.
- Add recreate-from-branch action if destroy/recreate is not already simple.
- Add stale workspace cleanup job.
- Add admin kill switch.
- Add basic provider resource/cost telemetry if available.
- Add clear workspace state for `unpushed changes`, `pushing`, `pushed`, and `push failed` if useful.

Required artifact:

- Dogfood operations note explaining restart, destroy, recreate, kill switch, cleanup, logs, and known failure modes.

Exit criteria:

- Internal users can recover from common boot failures without SSH/manual provider intervention.
- Admin can kill a workspace.
- Stale workspaces are cleaned up or reported.
- Cost/resource visibility is sufficient to notice runaway usage.
- Failure logs are visible enough to debug most dogfood issues.

Escalate before proceeding if:

- Provider has no reliable destroy/cleanup signal.
- Logs are inaccessible or routinely hide the real boot failure.
- Workspaces can continue billing without visibility.
- Internal users cannot recover from routine failures without engineering intervention.

## Cross-Phase Technical Questions

These questions may span multiple phases and should stay visible throughout implementation.

- How do we keep local Frontman behavior working at every step?
- How do we keep provider-specific concepts out of task/channel code?
- How do we ensure Git is the durability boundary and not provider disk?
- How do we avoid committing secrets or provider-generated files?
- How do we make every external side effect auditable?
- How do we make failure reasons user-visible without leaking secrets?
- How do we keep dogfood scope limited to `frontman` existing branches?
- What is the fastest rollback if cloud workspace code breaks production local usage?
- Which pieces are dogfood hacks that must be removed before public beta?

## Stop-And-Ask Triggers

Stop and ask the stakeholder before continuing if any of these happen:

- The implementation starts requiring support for repos other than `frontman`.
- The implementation starts requiring GitHub issue or PR automation.
- The implementation requires building custom microVM/sandbox infrastructure.
- Provider limitations require public unauthenticated previews.
- Secrets must be stored in plaintext or committed files.
- Auto-push could overwrite remote user changes.
- Local Frontman behavior would need to be broken or substantially rewritten.
- The provider cost model looks unacceptable for daily dogfood.
- The engineer cannot prove workspace destroy/cleanup.
- More than two days are spent debugging provider boot without a clear path forward.
