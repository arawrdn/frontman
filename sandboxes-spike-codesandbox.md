# CodeSandbox SDK Sandbox Spike

## Purpose

Prove whether CodeSandbox SDK can be the first managed sandbox provider for Frontman Cloud dogfood.

This is a provider spike, not product implementation. Do not build broad workspace UI, generic repo support, issue flows, PR automation, or provider abstraction code before this spike answers the core question.

Core question:

> Can CodeSandbox SDK boot the full `frontman` development stack from an existing branch, expose a usable authenticated preview with working WebSockets/HMR, provide logs, inject secrets safely enough for dogfood, and do so at acceptable cost?

## Recommendation Going In

CodeSandbox SDK is the first provider to spike because it is closest to Frontman's product shape:

- Programmatic cloud development environments.
- Templates based on Docker/Dev Container style setup.
- VM sizing controls.
- Command, terminal, filesystem, port, and preview APIs.
- Private preview host tokens.
- Lifecycle APIs for create, resume, hibernate, restart, shutdown, and delete.

Do not assume it works until the full Frontman stack is running. The docs suggest fit, but Phoenix, Vite HMR, ReScript watchers, Postgres, and multiple dev servers all need real validation.

## Scope

In scope:

- `frontman` repo only.
- Existing GitHub branch only.
- One CodeSandbox SDK template or sandbox setup path.
- One repeatable automation entrypoint that can create, boot, inspect, and destroy a `frontman` branch workspace without manual provider UI work.
- Full Frontman development stack, not partial preview-only mode.
- Browser preview for the hosted app.
- Sidecar feasibility notes for file operations, but no production sidecar implementation.
- Cost and reliability notes.

Out of scope:

- Arbitrary repos.
- GitHub issue start flow.
- PR creation.
- Commit/push automation.
- GitHub App integration.
- Public previews as the final access model.
- Provider abstraction in production code.
- Frontman workspace database schema.
- Long-term billing/quota system.
- In-house sandbox infrastructure.

## Frontman Runtime Requirements

The spike must validate the real dogfood stack, not a simplified hello world app.

Known current runtime pieces:

- `mise.toml` installs Node `24.9.0`, Yarn `4.10.3`, Elixir `1.19.3-otp-28`, Erlang `28.1.1`, `mprocs`, `mkcert`, and related tools.
- `.devcontainer/Dockerfile` installs Ubuntu system dependencies and `mise`.
- `mprocs.container.yml` starts ReScript, Phoenix, Vite client, Next.js test site, Astro bundle, Next.js bundle, and marketing server processes.
- The existing local container flow uses Postgres next to the dev container.
- The existing local worktree URLs include Phoenix, Vite, Next.js, Storybook, and Marketing.

Minimum services to validate:

| Service | Typical Port | Why It Matters |
|---|---:|---|
| Phoenix server | `4000` | Frontman server, auth, channels, ACP/MCP. |
| Vite client | `5173` | Frontman browser UI/client bundle. |
| Next.js test site | `3000` | Primary app preview dogfood target. |
| Marketing/Astro | `4321` | Confirms Astro/Vite-style dev behavior. |
| Storybook if practical | `6006` | Nice to validate, not required for spike pass. |
| Postgres | internal only | Required by Phoenix persistence. |

## Automation Requirement

The spike must prove that Frontman can automate CodeSandbox workspaces from repo metadata, not from manual provider dashboard steps.

Target interface:

```bash
./scripts/spikes/codesandbox-workspace create \
  --repo git@github.com:frontman-ai/frontman.git \
  --branch <existing-branch> \
  --template <frontman-template-id-or-name> \
  --vm-tier Small

./scripts/spikes/codesandbox-workspace status --workspace <provider-sandbox-id>
./scripts/spikes/codesandbox-workspace logs --workspace <provider-sandbox-id>
./scripts/spikes/codesandbox-workspace urls --workspace <provider-sandbox-id>
./scripts/spikes/codesandbox-workspace destroy --workspace <provider-sandbox-id>
```

The exact implementation language is open for the spike, but TypeScript is the preferred choice if the CodeSandbox SDK is best supported there.

The script may live under `scripts/spikes/` or another clearly temporary spike path. It should be treated as disposable proof code unless the provider wins.

The automation should own all provider actions needed for a workspace:

- Create sandbox from the chosen template.
- Inject non-repo secrets/environment values.
- Clone the repo.
- Checkout the requested existing branch.
- Run setup if the template does not already contain warm dependencies.
- Start Postgres and the dev process group.
- Wait for required ports.
- Generate or fetch private preview host tokens.
- Print stable provider metadata as JSON.
- Print preview URLs and service URLs.
- Fetch boot/runtime logs.
- Destroy the sandbox and verify cleanup.

The automation must not require:

- Opening the CodeSandbox dashboard.
- Manually entering port mappings.
- Manually starting dev servers.
- Manually copying preview URLs from provider UI.
- Manually SSHing into the sandbox for normal boot/debug flow.
- Editing files inside the sandbox by hand.

Manual provider account setup and API key creation are acceptable once. Workspace creation and operation must be automated after that.

### Project Manifest

Avoid hard-coded provider mapping scattered through the spike script. Put Frontman-specific boot metadata in one small manifest or config object.

Candidate path:

```text
scripts/spikes/codesandbox-frontman-workspace.json
```

Candidate shape:

```json
{
  "repo": "git@github.com:frontman-ai/frontman.git",
  "workdir": "/workspaces/frontman",
  "template": "frontman-dogfood-devcontainer",
  "vmTier": "Small",
  "setup": [
    "mise trust --all",
    "mise install --yes",
    "yarn install",
    "yarn rescript build",
    "cd apps/frontman_server && mix local.hex --force && mix local.rebar --force && mix deps.get",
    "cd apps/frontman_server && mix ecto.create || true",
    "cd apps/frontman_server && mix ecto.migrate"
  ],
  "processes": [
    {"name": "rescript", "command": "make clean && make rescript-build && make rescript-watch"},
    {"name": "server", "command": "cd apps/frontman_server && make dev-container"},
    {"name": "client", "command": "make dev-client"},
    {"name": "nextjs-bundle", "command": "cd libs/frontman-nextjs && yarn tsup --watch"},
    {"name": "astro-bundle", "command": "cd libs/frontman-astro && yarn tsup --watch"},
    {"name": "nextjs", "command": "make dev-nextjs"},
    {"name": "marketing", "command": "cd apps/marketing && yarn dev --host 0.0.0.0"}
  ],
  "ports": [
    {"name": "phoenix", "port": 4000, "required": true},
    {"name": "vite", "port": 5173, "required": true},
    {"name": "nextjs", "port": 3000, "required": true, "path": "/frontman"},
    {"name": "marketing", "port": 4321, "required": false},
    {"name": "storybook", "port": 6006, "required": false}
  ]
}
```

This manifest is intentionally dogfood-specific. It is not generic repo onboarding. The goal is to avoid hidden manual mapping while keeping the spike narrowly scoped to `frontman`.

### Auto-Discovery Versus Explicit Config

Use explicit config for the spike. Do not build generic framework detection yet.

Allowed automation:

- Read one Frontman-specific manifest.
- Read existing repo files like `mise.toml`, `mprocs.container.yml`, and `.devcontainer/Dockerfile` for validation.
- Detect actual open ports from CodeSandbox SDK rather than hard-coding generated URLs.
- Fail loudly when a required service is missing.

Avoid for this spike:

- Generic package-manager detection.
- Generic framework detection.
- Guessing arbitrary repo boot commands.
- Provider-specific state hidden only in CodeSandbox UI.

### Automation Output Contract

The `create` command should output machine-readable JSON so a future `WorkspaceProvider` can use the same shape.

Example:

```json
{
  "provider": "codesandbox",
  "sandboxId": "...",
  "branch": "...",
  "vmTier": "Small",
  "status": "running",
  "services": [
    {"name": "phoenix", "port": 4000, "url": "https://...", "required": true},
    {"name": "vite", "port": 5173, "url": "https://...", "required": true},
    {"name": "nextjs", "port": 3000, "url": "https://.../frontman", "required": true}
  ],
  "logs": {
    "setup": "...",
    "boot": "..."
  }
}
```

The output should be stable enough to paste into the spike report and later map into `WorkspaceProvider` callbacks.

## Provider Capabilities To Validate

CodeSandbox SDK claims or appears to provide:

- Sandbox creation from templates.
- Dev Container/Dockerfile-style template setup.
- Command execution and background commands.
- Interactive terminals.
- Filesystem read/write/list/watch APIs.
- Open port detection and preview URLs.
- Private hosts and host tokens.
- VM tier selection.
- Lifecycle controls: resume, hibernate, restart, shutdown, delete.
- Basic tracing/logging around commands and sandbox lifecycle.

The spike must turn each relevant claim into an observed result.

## Candidate VM Sizes

Start with `Small`, then test down/up only if needed.

| Tier | CPU | RAM | Cost/Hour | Spike Use |
|---|---:|---:|---:|---|
| Micro | 4 cores | 8 GB | `$0.2972` | Try only if Small succeeds and cost optimization matters. |
| Small | 8 cores | 16 GB | `$0.5944` | Recommended first full-stack attempt. |
| Medium | 16 cores | 32 GB | `$1.1888` | Use if Small fails from resource pressure. |

Pass/fail should record the smallest tier that can boot and run the stack without constant crashes, OOMs, or unusable latency.

## Spike Setup

### 1. Account And Access

Create or use a CodeSandbox account with SDK access.

Record:

- Plan/tier used.
- Concurrency limit.
- API request limit.
- VM tier availability.
- Whether private hosts/host tokens are available on the plan.
- Whether phishing/preview confirmation prompts appear.

### 2. API Key

Create an API key with the minimum scopes needed for sandbox/template lifecycle.

Store it outside the repo.

Do not commit API keys, host tokens, GitHub tokens, generated env files, or provider metadata that contains secrets.

### 3. GitHub Credential

Use the simplest read-only GitHub credential path needed to clone the private `frontman` repo for the spike.

Record:

- Clone method.
- Whether credentials are stored on disk in the sandbox.
- How credentials are removed or invalidated when the sandbox is destroyed.

Commit and push are explicitly out of scope for this provider spike. Prove runtime and preview first; Git durability can be bolted on above the winning provider later.

## Experiment A: Minimal SDK Smoke Test

Goal: prove SDK control works before touching Frontman.

Steps:

1. Create a sandbox via SDK.
2. Connect to it.
3. Run `node --version` or install/check Node.
4. Run a background HTTP server on port `3000`.
5. Wait for port `3000`.
6. Open the generated preview URL in a browser.
7. Generate/use a private host token if possible.
8. Delete the sandbox.

Pass criteria:

- SDK create/connect/command/port/delete works.
- Preview URL works in browser.
- Private host/token behavior is understood.

Fail criteria:

- Cannot create sandboxes programmatically.
- Cannot expose a port to browser.
- Private preview access is impossible or requires public unauthenticated URLs.

## Experiment B: Template Or Dev Container Boot

Goal: determine whether the existing Frontman devcontainer can be reused or needs a CodeSandbox-specific template.

Try in this order:

1. Build a CodeSandbox SDK template from the existing `.devcontainer/Dockerfile` if supported cleanly.
2. If that fails, create a minimal CodeSandbox-specific template that installs the same system dependencies and `mise`.
3. If `mise` is too slow or unreliable, create an explicit image/template that preinstalls Node/Yarn/Erlang/Elixir/mprocs.

Record:

- Template source path.
- Build command.
- Build duration.
- Build logs location.
- Any unsupported devcontainer fields.
- Whether rootless Podman behavior affects setup.
- Whether Docker Compose/Postgres is usable.

Pass criteria:

- A reusable template can start a sandbox with required runtimes available.
- `node --version`, `yarn --version`, `elixir --version`, and `mprocs --version` succeed.

Fail criteria:

- Template cannot install required runtimes.
- Elixir/Erlang cannot run.
- The environment cannot support Postgres in any reasonable form.

## Experiment C: Frontman Repo Clone And Setup

Goal: clone an existing branch and install/build enough to start dev.

This experiment must be driven by the spike automation entrypoint and manifest. Manual commands are allowed only to discover the correct sequence; once discovered, encode them in the automation before counting the experiment as passed.

Steps:

1. Run the automation `create` command against an existing branch.
2. Have automation create the sandbox from the candidate template.
3. Have automation clone `frontman` using the internal GitHub credential.
4. Have automation checkout the requested existing branch.
5. Have automation run setup commands from the manifest.
6. If the local worktree setup is too Podman-specific, encode the minimal explicit cloud setup sequence in the manifest and rerun from scratch.

Suggested setup sequence to test:

```bash
mise trust --all
mise install --yes
yarn install
yarn rescript build
cd apps/frontman_server
mix local.hex --force
mix local.rebar --force
mix deps.get
mix ecto.create || true
mix ecto.migrate
```

Record:

- Automation command used.
- Manifest/config fields used.
- Exact commands.
- Wall-clock duration.
- Peak disk usage.
- Peak memory if available.
- Any network/package registry failures.
- Any dependencies that require special system packages.

Pass criteria:

- Setup can be rerun from a clean sandbox with one command.
- Dependencies install.
- ReScript builds.
- Elixir deps install.
- Database can be created/migrated.
- The requested branch is checked out without manual intervention.

Fail criteria:

- Setup only works through manual provider UI or ad hoc terminal steps.
- Setup cannot complete on Small or Medium.
- Disk usage exceeds plan/provider limits.
- Required package registries or GitHub access cannot be reached.

## Experiment D: Full Stack Boot

Goal: boot the real development stack.

Boot must be automated from the same manifest. The script should discover actual opened ports from CodeSandbox and map them back to named services instead of relying on copied provider URLs.

Steps:

1. Run the automation boot path created in Experiment C.
2. Have automation start Postgres.
3. Have automation start the full dev process group using `mprocs.container.yml` if possible.
4. If `mprocs` is hard to supervise through the SDK, have automation start the same processes as separate background commands from the manifest.
5. Have automation wait for Phoenix, Vite, Next.js, and Marketing ports.
6. Have automation print service URLs as JSON.
7. Have automation capture boot logs.
8. Kill/restart one process through automation and verify logs/status remain understandable.

Record:

- Automation command used.
- Exact boot command.
- Whether `mprocs.container.yml` works unchanged.
- Which ports open.
- How provider-opened ports map to manifest service names.
- Time to first port.
- Time to all required ports.
- Process supervision approach.
- Where logs come from.
- Whether logs are streamable into Frontman.

Pass criteria:

- A clean workspace can boot with one automation command after provider/account credentials are configured.
- Phoenix, Vite, and Next.js all run simultaneously.
- Required service URLs are generated by automation, not copied from CodeSandbox UI.
- Logs are retrievable without manually SSHing into the provider UI.
- Failed boot produces enough logs to diagnose.

Fail criteria:

- Boot only works through manual commands that are not encoded in automation.
- Full stack cannot run due to CPU/RAM/disk limits.
- Long-running process logs are inaccessible.
- Dev processes die repeatedly without actionable errors.

## Experiment E: Preview, HMR, And WebSockets

Goal: prove the hosted app preview is usable for Frontman.

Steps:

1. Use the automation `urls` output to open the Next.js preview URL in a browser.
2. Open `/frontman` if available.
3. Confirm the browser can load the Frontman client from the Vite URL.
4. Confirm Phoenix channel/WebSocket connections work.
5. Edit a visible file in the sandbox.
6. Verify Next.js/Vite HMR updates without manual reload.
7. Repeat through a private host token URL.
8. If practical, test through a simple Frontman-owned reverse proxy prototype.

Record:

- Automation JSON URL output.
- Preview URL shape.
- Host token URL/cookie behavior.
- Whether iframe embedding works.
- Whether a provider warning/interstitial appears.
- WebSocket paths that connect.
- WebSocket paths that fail.
- HMR behavior.
- Any required `FRONTMAN_CLIENT_URL`, `FRONTMAN_HOST`, `PHX_HOST`, or origin config.

Pass criteria:

- Browser preview loads.
- The preview URL is produced by automation from provider port/host APIs.
- Frontman UI can connect to the hosted Phoenix server.
- HMR/WebSockets work or a documented manual reload fallback is acceptable for dogfood.
- Private access path works without making preview public.

Fail criteria:

- Preview requires manually copied provider dashboard URLs.
- Preview must be public to work.
- Phoenix channels cannot connect.
- Vite/Next HMR cannot work through provider routing or our proxy without major infrastructure work.
- Browser preview cannot be embedded or accessed in the expected Frontman UX.

## Experiment F: Filesystem And Sidecar Feasibility

Goal: decide whether CodeSandbox SDK filesystem/command APIs are enough for a first sidecar path or whether we need our own process inside the sandbox.

Steps:

1. Read a file through SDK filesystem API.
2. Write a file through SDK filesystem API.
3. List a directory.
4. Watch a directory or file if supported.
5. Run `git status` and `git diff` through command API.
6. Compare latency and output shape to Frontman's existing file tool expectations.

Record:

- File API latency.
- File size limits if encountered.
- Path traversal behavior and root constraints.
- Watch reliability on this repo.
- Whether command output is clean enough for MCP tool results.

Pass criteria:

- Basic read/write/list/diff operations are reliable.
- We can implement dogfood sidecar semantics using provider APIs or a small in-sandbox sidecar.

Fail criteria:

- File operations are too slow or unreliable.
- The provider API cannot constrain operations to the repo root.
- We would need a large custom sidecar before proving dogfood.

## Experiment G: Lifecycle And Cleanup

Goal: understand what Frontman must own for workspace lifecycle.

Lifecycle actions must use SDK/API automation. Provider dashboard checks are allowed only as secondary verification.

Steps:

1. Hibernate or suspend an idle sandbox through automation.
2. Resume it through automation.
3. Confirm processes, filesystem, preview URLs, and host tokens behavior.
4. Restart the sandbox through automation.
5. Confirm what persists and what resets.
6. Delete the sandbox through automation.
7. Verify provider API no longer shows billable resources.
8. Optionally verify in provider UI.

Record:

- Automation commands used.
- Hibernate time.
- Resume time.
- Whether dev processes survive hibernate.
- Whether preview URLs stay stable.
- Whether host tokens remain valid.
- Whether restart preserves workspace files.
- Delete semantics.
- Any remaining billable storage or resource.

Pass criteria:

- Lifecycle actions can be controlled without provider UI.
- Frontman can reliably stop/resume/delete workspaces.
- Destroy is verifiable.
- Failure states are observable.

Fail criteria:

- Lifecycle requires manual CodeSandbox dashboard operations.
- Workspaces continue billing after delete/hibernate without visibility.
- Resume is flaky or too slow for daily dogfood.
- Resources cannot be reliably cleaned up.

## Required Spike Artifact

At the end, produce a report with:

- Provider: CodeSandbox SDK.
- Account/plan used.
- Automation entrypoint path and usage.
- Manifest/config path and shape.
- Template approach.
- Exact commands.
- Machine-readable JSON output example.
- VM tier tested.
- Setup duration.
- Boot duration.
- Open ports.
- Preview URL shape.
- Private host token behavior.
- HMR/WebSocket result.
- Logs access method.
- Env/secrets method.
- Git clone method.
- Disk/memory observations.
- Lifecycle behavior.
- Destroy verification.
- Cost estimate.
- Blockers.
- Recommendation: proceed, retry with changes, or reject.

## Decision Gates

Proceed with CodeSandbox SDK only if all are true:

- A repeatable automation entrypoint can create, boot, inspect, and destroy a `frontman` branch workspace.
- Service/port mappings come from a manifest plus provider port discovery, not manual dashboard copying.
- Full Frontman stack boots on `Small` or `Medium`.
- Browser preview works.
- Phoenix/Vite/Next WebSockets and HMR either work or have an acceptable dogfood fallback.
- Preview can be made private or proxied through Frontman auth.
- Logs are available through SDK/API enough for user-visible boot failures.
- Git clone works without unsafe credential persistence.
- Destroy/recreate is reliable.
- Active workspace cost is acceptable for internal dogfood.

Reject or pause CodeSandbox SDK if any are true:

- Workspace creation, boot, URL discovery, or destroy depends on manual CodeSandbox UI actions.
- Preview must be public.
- HMR/WebSockets require major custom infrastructure.
- Full stack needs a tier too expensive for dogfood.
- Lifecycle/hibernate/delete behavior is unreliable or opaque.
- Git credentials or env secrets must be stored unsafely.
- CodeSandbox API limits block expected internal daily usage.

## Expected Outcome

The ideal successful result is:

```text
Frontman Server
  -> CodeSandbox WorkspaceProvider spike script
  -> CodeSandbox sandbox from Frontman template
  -> frontman branch checkout
  -> full dev stack running
  -> private/proxied preview URL
  -> browser opens /frontman
  -> file edit changes hosted preview
  -> sandbox destroyed and verified gone
```

If this works, CodeSandbox SDK becomes the leading provider for Phase 1 dogfood implementation behind a thin `WorkspaceProvider` abstraction.
