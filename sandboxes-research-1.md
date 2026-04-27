# Sandboxes Research 1: CodeSandbox SDK Spike

## Executive Summary

CodeSandbox SDK is promising enough to continue, but it is not yet proven for full Frontman dogfood.

What is proven:

- CodeSandbox SDK can create and connect to private sandboxes programmatically.
- Private preview host tokens work for a basic HTTP service.
- CodeSandbox can expose sandbox ports as browser URLs.
- CodeSandbox can build Docker-backed and devcontainer-shaped templates on `Micro`.
- A custom Micro template can provide the needed base OS/runtime prerequisites: Ubuntu 24.04, `mise`, Docker, Docker Compose, and Postgres client.
- Postgres via Docker Compose works inside the sandbox.
- The `frontman` repo can be cloned from an existing GitHub branch using an injected token without printing or committing the token.
- `mise install` succeeds and installs the expected Frontman toolchain.
- `yarn install` succeeds on Micro.

What is not yet proven:

- Full dependency/setup completion.
- ReScript build on Micro.
- Elixir deps and database migration on Micro.
- Full stack boot.
- Phoenix, Vite, Next.js, Marketing, and optional Storybook running together.
- WebSockets and HMR through CodeSandbox hosts or a Frontman proxy.
- Browser-cookie behavior for private host tokens.
- Long-running process log streaming quality.
- Reliable lifecycle cleanup without retry.

Current main blocker:

- `yarn rescript build` timed out after 10 minutes on Micro. After the timeout, the sandbox stopped accepting new SDK command shells with `Pitcher message shell/create timed out`. This suggests Micro may be underpowered for the current cold build path, or the spike needs a prewarmed template that includes more setup work before deciding Micro is insufficient.

Current recommendation:

- Continue CodeSandbox SDK evaluation, but change the spike shape.
- Stop growing one-off Frontman-only scripts as the main path.
- Do not build production Phoenix `WorkspaceProvider` code yet.
- Build a spike-level `WorkspaceBootPlan` plus a CodeSandbox runner shaped like the future provider contract.
- Keep Frontman as the hard dogfood boot plan, but make the runner generic enough that another repo is a different boot plan, not a different script.
- Treat Micro as not yet viable for full-stack dogfood until ReScript build and full process boot are proven.

## Scope And Constraints

This research follows the runtime-first CodeSandbox provider spike for Frontman Cloud dogfood.

Scope used:

- Repo: `frontman` only.
- Branch: `sandboxing_v2`.
- Provider: CodeSandbox SDK.
- VM tier tested successfully: `Micro`.
- VM tier attempted but blocked: `Small`.
- Focus: provider/runtime proof, not product implementation.
- Git push from sandbox: intentionally out of scope for this runtime-first pass.

Files created during the spike:

- `scripts/spikes/codesandbox-spike-report.md`
- `scripts/spikes/codesandbox-frontman-workspace.json`
- `scripts/spikes/codesandbox-smoke.mjs`
- `scripts/spikes/codesandbox-runtime-probe.mjs`
- `scripts/spikes/codesandbox-template-probe.mjs`
- `scripts/spikes/codesandbox-frontman-setup-probe.mjs`
- `scripts/spikes/codesandbox-frontman-template/`
- `scripts/spikes/codesandbox-devcontainer-template/`

## Account And Access Findings

The CodeSandbox API key is stored in 1Password item `wusfnxcboglwht5laihctuhj7y` under field `credential`.

The API credential permits at least `Micro` sandboxes.

`Small` failed during smoke testing with:

```text
VM tier exceeds max tier for this workspace
```

CodeSandbox docs list these prices:

| Tier | CPU | RAM | Cost/Hour |
|---|---:|---:|---:|
| Pico | 2 cores | 1 GB | `$0.0743` |
| Nano | 2 cores | 4 GB | `$0.1486` |
| Micro | 4 cores | 8 GB | `$0.2972` |
| Small | 8 cores | 16 GB | `$0.5944` |
| Medium | 16 cores | 32 GB | `$1.1888` |
| Large | 32 cores | 64 GB | `$2.3776` |
| XLarge | 64 cores | 128 GB | `$4.7552` |

Docs say the free Build plan supports 10 concurrent SDK VMs and Scale supports 250. Actual account limits observed via SDK showed 10 concurrent VMs during a running-sandbox query.

## SDK Capability Findings

Minimal SDK smoke test passed on Micro.

Observed successful capabilities:

- `sdk.sandboxes.create(...)`
- `sandbox.connect()`
- `client.commands.run(...)`
- `client.commands.runBackground(...)`
- `client.ports.waitForPort(...)`
- `sdk.hosts.createToken(...)`
- signed private preview URL fetch
- `sdk.sandboxes.delete(...)`, with retry caveats

Basic private preview URL shape:

```text
https://<sandbox-id>-<port>.csb.app/?preview_token=<redacted>
```

Example observed port host:

```text
ty9y23-3000.csb.app
```

HTTP fetch to the signed private URL returned `200`.

## Lifecycle And Cleanup Findings

Cleanup is not perfectly reliable on the first call.

Observed behavior:

- Inline delete inside scripts often failed with `Failed to delete VM <id>: An unexpected error occurred`.
- Retrying `sdk.sandboxes.delete(<id>)` separately usually succeeded.
- Some scripts needed two attempts.
- One setup run needed three failed inline attempts, then a later separate retry succeeded.
- Final check after the heavy Micro setup reported zero running VMs.

Operational implication:

- Any future provider integration must implement delete retry and verify with `listRunning()` or equivalent.
- We should not trust a single delete call as proof of cleanup.

## Default Micro Runtime Findings

The default SDK Micro sandbox is useful but not enough for Frontman cold setup.

Observed default runtime:

- OS: Ubuntu `20.04.6`
- User: root
- Shells: bash and zsh present
- Node: `20.12.1`
- npm: `10.5.0`
- corepack: `0.25.2`
- Git: `2.44.0`
- Docker: `23.0.1`
- Docker Compose: `2.16.0`
- Workspace disk: 30 GB total, about 16 GB free
- RAM: 8 GB
- Swap: 4 GB
- `pg_isready`: absent
- `mise`: absent or unusable in default probe

Conclusion:

- Default sandbox is not enough by itself.
- A custom template or devcontainer template is required.

## Template Findings

### Custom CodeSandbox Template

A custom CodeSandbox template was created at:

```text
scripts/spikes/codesandbox-frontman-template/
```

It uses `.codesandbox/Dockerfile` and `.codesandbox/tasks.json`.

Build command used:

```bash
CSB_API_KEY="$(op item get "wusfnxcboglwht5laihctuhj7y" --fields credential --reveal)" \
  npx @codesandbox/sdk@2.4.2 build "codesandbox-frontman-template" \
  --vm-tier Micro \
  --vm-build-tier Micro \
  --alias frontman-dogfood-micro \
  --ci
```

First build attempt with `--ports 3000` failed because no task opened port 3000. Rebuild without `--ports` succeeded.

Successful template output:

- Alias: `codesandbox-frontman-template@frontman-dogfood-micro`
- Template ID: `pt_DYmheRvT8V4oPToPbV3Vx8`
- Verify URL: `https://codesandbox.io/s/vz9897`

Runtime from this template:

- OS: Ubuntu `24.04.4`
- `mise`: `2026.4.23`
- Postgres client: `16.13`
- Docker: `23.0.1`
- Docker Compose: `2.16.0`
- Workspace disk: 30 GB total, about 15 GB free before clone/setup
- RAM: 8 GB
- Swap: 8 GB

Postgres via Docker Compose passed:

- `docker compose up -d db` worked with `postgres:16-alpine`.
- `pg_isready -h localhost -U postgres` eventually reported accepting connections.

### Devcontainer Template Support

CodeSandbox supports devcontainer-shaped templates.

A devcontainer-shaped template was created at:

```text
scripts/spikes/codesandbox-devcontainer-template/
```

It used:

- `.devcontainer/devcontainer.json`
- `.devcontainer/Dockerfile`
- `ghcr.io/devcontainers/features/git:1`

Build succeeded on Micro.

Successful devcontainer template output:

- Alias: `codesandbox-devcontainer-template@frontman-devcontainer-micro`
- Template ID: `pt_UXQVCqkHbJgxvQqvoHf8L2`
- Verify URL: `https://codesandbox.io/s/qcyxnd`

Conclusion:

- CodeSandbox can consume and build a `.devcontainer/devcontainer.json` template.
- The earlier custom `.codesandbox/Dockerfile` path was not the only viable template route.
- Future work should prefer devcontainer-shaped templates if we want closer parity with existing repo conventions.

## Existing Frontman Devcontainer Portability

The existing `.devcontainer/Dockerfile` is largely reusable as a runtime base.

The existing `.devcontainer/post-create.sh` should not be used unchanged in CodeSandbox.

Reasons:

- It searches for the repo under `/workspaces/*/mise.toml`.
- CodeSandbox workspace root is `/project/workspace`.
- It generates local worktree hashes for `*.frontman.local` URLs.
- It assumes local Caddy and dnsmasq routing.
- It assumes `host.docker.internal` for database connectivity.
- It writes `.env.devpod` and `.dev.overrides.env` with DevPod/local networking assumptions.
- It mutates `apps/frontman_server/config/dev.exs` to point at a Docker gateway IP.
- It prints host-file and Caddy setup instructions that do not apply to CodeSandbox.

Conclusion:

- CodeSandbox devcontainer support: yes.
- Frontman current devcontainer post-create flow unchanged: no.
- Best path is to reuse the Dockerfile/devcontainer structure but replace the post-create flow with explicit CodeSandbox provider setup commands.

## Frontman Repo Clone Findings

The spike branch was initially local-only, so CodeSandbox could not clone it.

The branch was pushed to origin:

```bash
git push -u origin sandboxing_v2
```

After that, clone passed.

Clone method that worked:

- HTTPS clone.
- Temporary `GIT_ASKPASS` script inside the sandbox.
- GitHub token passed through SDK command `env`, not embedded directly into the command output.
- `GIT_TERMINAL_PROMPT=0` to fail loudly instead of hanging.
- `--single-branch --branch sandboxing_v2 --filter=blob:none` to reduce clone cost.

Observed checked out commit:

```text
af828141eda8291b78f0801413c1285f351abc47
```

Observed remote:

```text
origin https://github.com/frontman-ai/frontman.git (fetch) [blob:none]
origin https://github.com/frontman-ai/frontman.git (push)
```

Credential conclusion:

- HTTPS token clone works.
- For product dogfood, use a GitHub App/bot credential or scoped deploy credential.
- Do not rely on local `gh auth token` except for spike scripts.

## Toolchain Setup Findings

After clone, `mise trust --all && mise install --yes` succeeded on Micro.

Verified tool versions through `mise exec -- ...`:

- Node `24.9.0`
- Yarn `4.10.3`
- Elixir `1.19.3`
- Erlang OTP `28`
- `mprocs 0.7.1`

Important detail:

- A plain command shell did not automatically activate `mise` shims.
- Spike scripts needed `mise exec -- ...` instead of assuming `.bashrc` activation.

Resource state after clone and `mise install`:

- Disk: `/project/workspace` about 54% used with 14 GB available.
- Memory: about 5.7 GB free out of 8 GB.
- Swap: 8 GB, unused.

## Dependency Setup Findings

Postgres setup passed:

- `docker compose up -d db` passed.
- `pg_isready -h localhost -U postgres` passed after several retries.

Yarn install passed:

- `mise exec -- yarn install` completed in about 1m33s.
- Existing peer/build warnings appeared, but install exited successfully.

ReScript build did not pass on Micro:

- `mise exec -- yarn rescript build` timed out after 10 minutes.
- After the timeout, subsequent command creation failed with `Pitcher message shell/create timed out`.

Elixir setup was not validated:

- The Elixir deps/migration command was attempted after the ReScript timeout.
- The SDK control plane was already degraded, so the command failed to start.

Conclusion:

- Micro handles clone, toolchain install, Postgres, and Yarn install.
- Micro cold ReScript build is currently the blocker.
- It is unclear whether Micro is fundamentally too small or whether prewarming/caching would make it viable.

## Preview And Host Token Findings

Basic preview passed for a smoke HTTP server.

Observed behavior:

- A background Node HTTP server listened on `0.0.0.0:3000`.
- `client.ports.waitForPort(3000)` found the port.
- CodeSandbox exposed `https://<sandbox-id>-3000.csb.app`.
- Private sandbox signed URL included `preview_token`.
- Fetching the signed URL returned HTTP `200`.

Not yet tested:

- Browser-opening behavior.
- Token cookie behavior after opening signed URL.
- iframe embedding.
- Phoenix WebSockets.
- Vite HMR.
- Next.js HMR.
- Frontman-authenticated reverse proxy.

## Logs And Command Output Findings

SDK command output is retrievable for normal commands.

Observed limitations:

- Long commands can produce very large ANSI-heavy logs.
- When a command timed out and appeared to keep running, later SDK command creation failed.
- This needs better background command supervision before full-stack boot.

Implication:

- Product code should not run long setup/build commands as opaque `run(...)` calls without cancellation and log streaming.
- Use background commands or CodeSandbox tasks for dev processes.
- Add timeouts, kill/restart behavior, and log collection from the start.

## Full Stack Boot Status

Full stack boot has not been attempted yet.

Reason:

- The setup phase has not completed on Micro.
- ReScript build timed out before Elixir deps/migration and dev process boot could be validated.

Expected future boot problems:

- `mprocs.container.yml` assumes local worktree routing via `WORKTREE_HASH` and `*.frontman.local`.
- CodeSandbox needs provider-specific host/origin values.
- Phoenix, Vite, and Next.js WebSocket/HMR origins need explicit mapping.
- Long-running process supervision should use SDK background commands or tasks, not a single opaque shell.

## Security And Secrets Notes

Secrets were not committed.

CodeSandbox API key:

- Read from 1Password item `wusfnxcboglwht5laihctuhj7y`.
- Value was not printed.

GitHub token:

- Read locally with `gh auth token` for spike use.
- Passed to sandbox commands through SDK `env`.
- Used by a temporary `GIT_ASKPASS` script.
- The askpass script was removed after successful clone.

Open questions:

- Provider-managed env var injection for long-running dev processes.
- Whether `op` should run inside CodeSandbox for dogfood secrets.
- How to avoid secrets leaking in command logs.
- How to inject WorkOS and other server secrets safely enough for dogfood.

## Decision Gates So Far

| Gate | Result | Notes |
|---|---|---|
| SDK create/connect | Pass | Works on Micro. |
| SDK delete | Partial | Needs retry and verification. |
| Private preview token | Initial pass | HTTP fetch works; browser/cookie behavior pending. |
| Port discovery | Pass | `waitForPort` works for smoke server. |
| Docker template support | Pass | `.codesandbox/Dockerfile` template builds. |
| Devcontainer support | Pass | `.devcontainer/devcontainer.json` template builds. |
| Postgres feasibility | Pass | Docker Compose Postgres works. |
| GitHub clone | Pass | After pushing remote branch; HTTPS token/askpass works. |
| Toolchain install | Pass | `mise install` works. |
| Yarn install | Pass | Completed on Micro. |
| ReScript build | Fail/Blocked | Timed out after 10 minutes on Micro. |
| Elixir deps/migration | Pending | Not reached cleanly. |
| Full stack boot | Pending | Not attempted. |
| HMR/WebSockets | Pending | Not attempted. |
| Cost viability | Pending | Micro cost is attractive, but runtime viability not proven. |

## Corrected Spike Direction

The initial disposable scripts were useful for provider physics: create, connect, private ports, templates, clone, Postgres, and cold setup stress. They are not the right shape for validating future customer workspaces.

The next spike should validate this question instead:

> Can CodeSandbox implement a generic Frontman workspace boot contract, with repo-specific behavior represented as data?

That means the provider-specific code should be a reusable runner, not a growing pile of Frontman-specific shell commands.

### Target Spike Abstractions

Introduce a spike-only `WorkspaceBootPlan` JSON shape.

Candidate shape:

```json
{
  "name": "frontman-dogfood",
  "repo": "https://github.com/frontman-ai/frontman.git",
  "branch": "sandboxing_v2",
  "workspaceDir": "/project/workspace/frontman",
  "template": {
    "provider": "codesandbox",
    "id": "codesandbox-devcontainer-template@frontman-devcontainer-micro",
    "vmTier": "Micro"
  },
  "clone": {
    "method": "https-token",
    "singleBranch": true,
    "partialClone": true
  },
  "setup": [
    {
      "name": "install-toolchain",
      "command": "mise trust --all && mise install --yes",
      "timeoutSeconds": 1200
    },
    {
      "name": "install-js-deps",
      "command": "mise exec -- yarn install",
      "timeoutSeconds": 1200
    }
  ],
  "services": [
    {
      "name": "postgres",
      "command": "docker compose up -d db",
      "healthCheck": "pg_isready -h localhost -U postgres",
      "required": true
    },
    {
      "name": "vite",
      "command": "mise exec -- make dev-client",
      "port": 5173,
      "required": true
    }
  ],
  "ports": [
    {"name": "phoenix", "port": 4000, "required": true},
    {"name": "vite", "port": 5173, "required": true},
    {"name": "nextjs", "port": 3000, "path": "/frontman", "required": true}
  ],
  "env": {
    "FRONTMAN_INTERNAL_DEV": "true"
  }
}
```

This is still explicit and dogfood-friendly, but it changes what is being tested. CodeSandbox becomes the executor of a normalized boot plan rather than a hand-authored Frontman script.

### Target Runner Contract

Create a spike-only CodeSandbox runner with provider-shaped operations:

```text
createWorkspace(bootPlan, secrets)
runSetup(workspace, bootPlan)
startServices(workspace, bootPlan)
getStatus(workspace)
getLogs(workspace)
getUrls(workspace)
destroyWorkspace(workspace)
```

The runner should return normalized JSON that resembles a future `WorkspaceProvider` response:

```json
{
  "provider": "codesandbox",
  "workspaceId": "...",
  "bootPlan": "frontman-dogfood",
  "branch": "sandboxing_v2",
  "status": "running",
  "services": [
    {"name": "vite", "port": 5173, "url": "https://...", "status": "ready"}
  ],
  "steps": [
    {"name": "clone", "status": "passed", "durationMs": 12345},
    {"name": "install-js-deps", "status": "passed", "durationMs": 93000}
  ],
  "logs": {
    "setup": "...",
    "services": "..."
  }
}
```

### What This Validates For Future Customers

This adjusted plan validates the durable product thesis:

- Customer-specific behavior can live in a boot plan.
- CodeSandbox-specific behavior can live in a provider runner.
- Frontman can later generate or edit boot plans from repo detection, devcontainers, package scripts, and user config.
- Preview URL discovery, logs, lifecycle, secrets, and command execution can normalize into Frontman-owned concepts.
- The same runner can be tested against both `frontman` and a small representative fixture repo.

### What Remains Dogfood-Specific

For now, these should stay explicit and narrow:

- The `frontman` repo allowlist.
- Existing branch start flow.
- Frontman-specific setup commands.
- Frontman-specific service list and ports.
- Manual internal credentials.

The point is not to build generic repo onboarding in the spike. The point is to avoid baking provider validation into Frontman-only imperative code.

## Current Conclusion

CodeSandbox SDK remains a viable provider candidate, but the current Micro cold setup path is not enough to declare success.

Most provider primitives are promising:

- API lifecycle works enough for experimentation.
- Private preview tokens exist.
- Port URLs are simple.
- Docker and devcontainer templates work.
- Docker Compose works for Postgres.
- File/command APIs appear rich enough for early sidecar feasibility, though not yet tested deeply.

The biggest concern is compute and control-plane behavior under Frontman build load:

- Micro timed out on ReScript build.
- After the timeout, SDK command creation degraded.
- Cleanup is retry-sensitive.

## Recommended Next Experiments

1. Replace the current Frontman-specific setup probe with a spike-level `WorkspaceBootPlan` JSON file.
2. Replace ad hoc scripts with a CodeSandbox runner that consumes a boot plan and exposes provider-shaped operations.
3. Port the current Frontman setup into `frontman.boot-plan.json` without hiding commands in runner code.
4. Add one tiny representative fixture boot plan, ideally a minimal Vite or Next.js repo, to prove the runner is not Frontman-only.
5. Build a prewarmed devcontainer template that runs `mise install` during template build, then reference it from the Frontman boot plan.
6. Consider adding `yarn install` to template setup if template build time and cache behavior are acceptable.
7. Retry ReScript build on Micro from the prewarmed template via the boot-plan runner.
8. If ReScript still times out, unblock/test `Small` because `Micro` is probably not viable for full-stack dogfood.
9. Once setup completes, test Elixir deps and database migration through the runner.
10. Then boot Phoenix, Vite, Next.js, and Marketing as separate background services defined in the boot plan.
11. Validate CodeSandbox host URLs, Phoenix WebSocket, Vite HMR, and Next.js HMR.
12. Test filesystem APIs for read/write/list/watch and compare to expected sidecar semantics.
13. Test lifecycle explicitly: hibernate, resume, restart, delete, and verify no running/billable VMs remain.

## Practical Implementation Notes

Do not generalize yet.

Keep the spike dogfood-specific:

- `frontman` repo only.
- Existing branch only.
- Explicit setup commands.
- Explicit process list.
- Explicit port mapping.
- No product database schema yet.
- No generic repo onboarding.
- No GitHub issue/PR flow.

The best near-term provider automation shape is a spike-level boot-plan runner, not production `WorkspaceProvider` code and not a pile of Frontman-only scripts.

The runner can be disposable, but the contract it tests should be durable.
