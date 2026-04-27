# CodeSandbox SDK Provider Spike Report

## Status

- Provider: CodeSandbox SDK
- Scope: `frontman` repo, existing branch, runtime-first validation
- Current recommendation: pending experiments
- Current branch tested: `sandboxing_v2`
- API credential source: 1Password item `wusfnxcboglwht5laihctuhj7y`
- Manifest/config path: `scripts/spikes/codesandbox-frontman-workspace.json`

## Decision Gate Summary

| Gate | Result | Evidence |
|---|---|---|
| SDK can create/connect/delete sandbox | Partial | Create/connect worked on `Micro`; inline delete failed but separate delete retry succeeded. |
| Sandbox can expose browser preview URL | Pass | `client.ports.waitForPort(3000)` returned `ty9y23-3000.csb.app`; signed URL fetched with HTTP `200`. |
| Private host/token behavior understood | Initial pass | `privacy: "private"` plus `sdk.hosts.createToken(...)` generated signed URL with `preview_token`; browser-cookie behavior still pending. |
| Template/devcontainer path supports required runtimes | Pass | Devcontainer-shaped Micro template builds and starts with Ubuntu 24.04, `mise`, Postgres client, Docker, and Docker Compose. |
| Repo clone and branch checkout works | Pass | `sandboxing_v2` cloned from origin on Micro after branch push; `git rev-parse HEAD` returned `af828141eda8291b78f0801413c1285f351abc47`. |
| Dependencies install and database migrates | Pass | On Micro with devcontainer template and `DB_HOST=db`, Postgres, `yarn install`, ReScript build, Elixir deps, DB create, and migrations all completed. |
| Full stack boots | Pass for required services | Micro sandbox `pk2c9p` opened Phoenix `4000`, Vite `5173`, and Next.js `3000`; optional Marketing/Astro `4321` timed out. |
| Phoenix, Vite, and Next.js run simultaneously | Pass | Background commands started via SDK and required ports all reported ready. |
| Logs are retrievable without provider UI | Pass | `runBackground(...).open().onOutput(...)` captured Phoenix, Vite, Next.js, bundle, and ReScript logs. |
| Preview, WebSockets, and HMR work or fallback is acceptable | Partial | Vite HMR bind issue fixed on pushed branch; browser-level preview, Phoenix WebSocket, and HMR behavior still need validation. |
| Secrets/env injection path is safe enough for dogfood | Pending | |
| Destroy/recreate is reliable | Partial | Delete remains flaky; `pk2c9p` failed first delete attempt and succeeded on retry. |
| Cost is acceptable for internal dogfood | Pending | |

## Account And Access

- Plan/tier used: current API credential permits at least `Micro`; `Small` was rejected with `VM tier exceeds max tier for this workspace`.
- Concurrency limit: docs say Build/free plan supports 10 concurrent SDK VMs, Scale supports 250, Enterprise custom; actual account limit pending.
- API request limit: pending
- VM tier availability: docs expose SDK `VMTier` and `VMTier.fromSpecs`; direct SDK create/update supports up to Small unless a custom template is built for higher tiers. Actual account/workspace rejected `Small` during smoke test; `Micro` succeeded.
- Private host/token availability: docs support `privacy: "private"`, `sdk.hosts.createToken(sandbox.id)`, signed URLs, headers, cookies, and token expiration.
- Preview warning/interstitial behavior: pending

## Credential Handling

- CodeSandbox API key: read from 1Password item `wusfnxcboglwht5laihctuhj7y`; value must not be printed or committed.
- GitHub clone credential: pending
- GitHub clone credential: local `gh auth token` injected into SDK command env, consumed through temporary `GIT_ASKPASS`, then removed inside the sandbox command.
- Secrets/env vars: boot probe passed runtime env directly to SDK commands. This is workable for spike automation but not a final dogfood secret model.
- Secret persistence observations: no secret values are written to report output by current probes; preview tokens are redacted. Need explicit filesystem/history audit before productizing.

## Runtime Requirements Observed In Repo

- Tool versions: Node `24.9.0`, Yarn `4.10.3`, Elixir `1.19.3-otp-28`, Erlang `28.1.1`, `mprocs` `0.7.1`, `mkcert` `1.4.4` from `mise.toml`.
- Devcontainer/template source: `.devcontainer/Dockerfile` based on Ubuntu `24.04`; installs build tooling, git/curl/wget/unzip, SSL libraries, inotify, Postgres client, Erlang/Elixir native deps, mkcert deps, jq, sudo, locales, and `mise` for user `vscode`.
- Existing process supervisor: `mprocs.container.yml` for containerized worktrees.
- Required services: Phoenix `4000`, Vite `5173`, Next.js `3000`, Marketing/Astro `4321` optional, Storybook `6006` optional
- Postgres approach: local container worktree uses sibling Postgres container and `pg_isready -h localhost -U postgres`; CodeSandbox path must prove whether provider supports an equivalent internal Postgres process/container.
- Local routing assumptions: `mprocs.container.yml` derives `PHX_HOST`, `FRONTMAN_CLIENT_URL`, and `FRONTMAN_HOST` from `WORKTREE_HASH` plus local Caddy hostnames (`*.frontman.local`). CodeSandbox likely needs provider preview URLs or a provider-aware env mapping instead of using this file unchanged.
- Server secret behavior: `apps/frontman_server/Makefile` uses `op run --env-file=envs/.dev.secrets.env -- mix phx.server` locally and `make dev-container` assumes env vars are already injected.

## Experiment A: Minimal SDK Smoke Test

Goal: prove SDK create/connect/command/port/delete before touching Frontman.

- Automation command: `CSB_API_KEY="$(op item get "wusfnxcboglwht5laihctuhj7y" --fields credential --reveal)" CSB_VM_TIER=Micro node "codesandbox-smoke.mjs"` from `scripts/spikes/`.
- Sandbox/template used: default SDK sandbox, no custom template yet.
- VM tier: `Small` failed with `VM tier exceeds max tier for this workspace`; `Micro` succeeded.
- Commands run: `node --version`; background Node HTTP server on `0.0.0.0:3000`.
- Port tested: `3000`.
- Preview URL shape: `https://<sandbox-id>-3000.csb.app/?preview_token=<redacted>`.
- Private host/token behavior: `privacy: "private"` plus `sdk.hosts.createToken(sandbox.id, {expiresAt})`; signed URL fetched successfully with HTTP `200`.
- Logs method: command output available through SDK command APIs; runtime log streaming not fully tested yet.
- Destroy verification: inline delete twice returned `Failed to delete VM <id>: An unexpected error occurred`, but immediate separate `sdk.sandboxes.delete(<id>)` attempts succeeded for `3hrysn` and `ty9y23`.
- Result: pass for SDK create/connect/command/port/private-preview fetch; partial/follow-up required for reliable cleanup behavior.

Observed JSON output:

```json
{
  "provider": "codesandbox",
  "experiment": "minimal-sdk-smoke-test",
  "sandboxId": "ty9y23",
  "vmTier": "Micro",
  "privacy": "private",
  "nodeVersion": "v20.12.1",
  "port": {
    "port": 3000,
    "host": "ty9y23-3000.csb.app"
  },
  "previewUrlRedacted": "https://ty9y23-3000.csb.app/?preview_token=%5Bredacted%5D",
  "previewFetchStatus": 200,
  "destroyed": false,
  "deleteError": "Failed to delete VM ty9y23: An unexpected error occurred"
}
```

Relevant SDK evidence from docs:

- Quickstart uses `CSB_API_KEY`, `new CodeSandbox()`, `sdk.sandboxes.create()`, `sandbox.connect()`, and `client.commands.run(...)`.
- Default sandbox privacy is `public-hosts`; private previews require `privacy: "private"` and host tokens.
- Open ports are automatically exposed as `https://<sandbox-id>-<port>.csb.app`.
- `client.ports.waitForPort(port)` waits for service readiness.
- `client.hosts.getUrl(port)` or server-side `sdk.hosts.getUrl(hostToken, port)` generates signed preview URLs.

## Experiment B: Template Or Dev Container Boot

Goal: determine whether the existing Frontman devcontainer can be reused or needs a CodeSandbox-specific template.

- Default sandbox runtime probe: `Micro`, sandbox `8x84j8`, deleted on second retry.
- Template source path: `scripts/spikes/codesandbox-devcontainer-template/` for devcontainer-first validation; `scripts/spikes/codesandbox-frontman-template/` remains the earlier `.codesandbox/Dockerfile` fallback proof.
- Build/create command: `CSB_API_KEY="$(op item get "wusfnxcboglwht5laihctuhj7y" --fields credential --reveal)" npx @codesandbox/sdk@2.4.2 build "codesandbox-frontman-template" --vm-tier Micro --vm-build-tier Micro --alias frontman-dogfood-micro --ci` from `scripts/spikes/`.
- Build duration: under 15 minutes; exact wall-clock not captured. First build with `--ports 3000` failed because no task opened port 3000; rebuild without `--ports` succeeded.
- Runtime checks from default `Micro`: Ubuntu `20.04.6`, root user, bash and zsh present, Node `20.12.1`, npm `10.5.0`, corepack `0.25.2`, Git `2.44.0`, Docker `23.0.1`, Docker Compose `2.16.0`, 30 GB `/project/workspace` disk with 16 GB free, 8 GB RAM plus 4 GB swap. `pg_isready` absent. `mise` absent or command probe timed out.
- Runtime checks from custom `Micro` template sandbox `mrt48j`: Ubuntu `24.04.4`, `mise` `2026.4.23`, Postgres client `16.13`, Docker `23.0.1`, Docker Compose `2.16.0`, 30 GB workspace disk with 15 GB free, 8 GB RAM plus 8 GB swap. `node` is intentionally absent before running `mise install`.
- Unsupported devcontainer fields: pending
- Postgres feasibility: pass for template-level feasibility. `docker compose up -d db` using `postgres:16-alpine` succeeded, and `pg_isready -h localhost -U postgres` reported accepting connections after two retries.
- Template result: build succeeded. Alias `codesandbox-frontman-template@frontman-dogfood-micro` now references template `pt_DYmheRvT8V4oPToPbV3Vx8`. CodeSandbox verification URL: `https://codesandbox.io/s/vz9897`.
- Devcontainer support test: pass for parser/build support. A devcontainer-shaped template at `scripts/spikes/codesandbox-devcontainer-template/` built successfully with `.devcontainer/devcontainer.json`, `.devcontainer/Dockerfile`, and the `ghcr.io/devcontainers/features/git:1` feature. Latest alias `codesandbox-devcontainer-template@frontman-devcontainer-postgres-micro` references template `pt_GdrZdyeyuTzHCKav8RRpbG`. CodeSandbox verification URL: `https://codesandbox.io/s/xy77gy`.
- Devcontainer runtime probe: pass for Ubuntu `24.04.4`, `mise` `2026.4.24`, Postgres client `16.13`, Docker `23.0.1`, Docker Compose `2.16.0`, 30 GB workspace disk with ~15 GB free, 8 GB RAM and 8 GB swap. Node is intentionally absent before `mise install`.
- Devcontainer Postgres networking: partial/pass with explicit network attach. `docker compose up -d db` starts `workspace-db-1`, but `pg_isready` from inside the devcontainer fails for `localhost`, `host.docker.internal`, and default gateway. After `docker network connect workspace_default devcontainer`, `pg_isready -h db -U postgres` and `pg_isready -h workspace-db-1 -U postgres` pass. Frontman cloud boot should set `DB_HOST=db` and connect the devcontainer to the Compose network after starting Postgres.
- Existing Frontman devcontainer portability caveat: current `.devcontainer/post-create.sh` is local/DevPod-worktree specific. It searches `/workspaces/*/mise.toml`, generates `*.frontman.local` Caddy/dnsmasq URLs from a worktree hash, assumes `host.docker.internal`, writes `.dev.overrides.env`, mutates `apps/frontman_server/config/dev.exs`, and prints local host-file/Caddy instructions. CodeSandbox can build devcontainers, but this post-create flow should not be used unchanged for provider automation.
- Runtime validation result: pass for template/runtime prerequisites. Next blocker is private GitHub clone credential for the `frontman` repo.

Relevant SDK evidence from docs:

- Templates are built with `npx @codesandbox/sdk build ./template --ports <ports>` and return a template ID.
- `.codesandbox/Dockerfile` is supported from SDK `2.3.0`; installed package latest is `2.4.2`.
- Docker templates must include `zsh` because it is CodeSandbox's default shell.
- Docker Compose is documented for additional services such as Postgres, but compose startup must be handled by tasks or automation.
- Setup tasks must not run long-lived dev servers.

## Experiment C: Frontman Repo Clone And Setup

Goal: clone an existing branch and install/build enough to start dev.

- Branch: `sandboxing_v2`; pushed to `origin/sandboxing_v2` during the spike because it was initially local-only.
- Automation command: `CSB_API_KEY="$(op item get "wusfnxcboglwht5laihctuhj7y" --fields credential --reveal)" GITHUB_TOKEN="$(gh auth token)" CSB_VM_TIER=Micro FRONTMAN_BRANCH="sandboxing_v2" node "codesandbox-frontman-setup-probe.mjs"` from `scripts/spikes/`.
- Manifest/config fields: repo `git@github.com:frontman-ai/frontman.git`, branch `sandboxing_v2`, workdir `/project/workspace/frontman`, VM tier `Small`, privacy `private`, explicit setup commands, explicit process commands, and named ports.
- Exact setup commands tested so far: HTTPS clone using `GIT_ASKPASS` and local `gh` token passed through SDK command env; `mise trust --all && mise install --yes`; tool checks via `mise exec -- ...`; `docker compose up -d db && docker network connect workspace_default devcontainer || true`; `pg_isready -h db -U postgres`; `yarn install`; `yarn rescript build`; `mix local.hex --force && mix local.rebar --force && mix deps.get && mix ecto.create || true && mix ecto.migrate` with `DB_HOST=db`.
- Wall-clock duration: full setup completed within the 45 minute command timeout. `yarn install` reported about 1m32s. ReScript build completed within the 10 minute per-command timeout. Exact total setup duration still needs instrumented timing.
- Disk usage: after clone and `mise install`, `/project/workspace` was 54% used with 14 GB available. After dependencies, `/project/workspace` was 61% used with 12 GB available.
- Memory observations: after clone and `mise install`, 8 GB RAM with about 5.7 GB free and 8 GB swap unused. After dependencies, 8 GB RAM with 1.9 GB free, 5.4 GB buff/cache, 6.6 GB available, and swap unused.
- Network/package failures: initial clone failed until `sandboxing_v2` was pushed to origin; HTTPS clone auth works using temporary `GIT_ASKPASS` with token passed by SDK env. `--filter=blob:none` reduced clone cost and left remote fetch as `[blob:none]`. `yarn install` completed with existing peer/build warnings only.
- Toolchain result: pass. Verified Node `24.9.0`, Yarn `4.10.3`, Elixir `1.19.3`, Erlang OTP `28`, and `mprocs 0.7.1`.
- Dependency result: pass on `Micro` with devcontainer template. Postgres compose/readiness, `yarn install`, ReScript build, Elixir deps, DB create, and migrations all pass.
- Result: clone/checkout, toolchain setup, Postgres, Yarn install, ReScript build, and Phoenix database setup pass on `Micro`. Previous ReScript timeout appears to have been tied to the older template/probe state rather than a hard Micro blocker.
- Cleanup observation: sandbox `py6k4m` required three delete attempts; delete eventually succeeded. Lifecycle reliability remains a specific follow-up.

## Experiment D: Full Stack Boot

Goal: boot the real development stack.

- Automation command: `CSB_API_KEY=$(op signin --account my.1password.com >/dev/null && op item get wusfnxcboglwht5laihctuhj7y --fields label=credential --reveal) GITHUB_TOKEN=$(gh auth token) CSB_VM_TIER=Micro FRONTMAN_BRANCH="sandboxing_v2" node "scripts/spikes/codesandbox-frontman-boot-probe.mjs"`.
- Sandbox/template used: devcontainer template alias `codesandbox-devcontainer-template@frontman-devcontainer-postgres-micro`; sandbox `pk2c9p`.
- Branch/commit: `sandboxing_v2` at `230276f99fa9f19bab9ffe693a97ddf4683413e6`.
- Boot command/process model: SDK background commands for ReScript watch, Phoenix, Vite client, Next.js bundle watch, Astro bundle watch, Next.js app, and Marketing/Astro app. This avoids local-only `mprocs.container.yml` routing assumptions.
- `mprocs.container.yml` compatibility: not portable unchanged. It assumes `WORKTREE_HASH`, local Caddy/dnsmasq, `*.frontman.local`, and host/container conventions that do not map directly to CodeSandbox preview hosts.
- Open ports: required ports passed. Phoenix `4000`, Vite `5173`, and Next.js `3000` all opened. Optional Marketing/Astro `4321` timed out after 120s.
- Required service URLs: `https://pk2c9p-4000.csb.app?preview_token=[redacted]`, `https://pk2c9p-5173.csb.app?preview_token=[redacted]`, and `https://pk2c9p-3000.csb.app?preview_token=[redacted]`.
- Logs source: pass. SDK background command handles provided logs for Phoenix, Vite, Next.js, ReScript, and package bundle watchers.
- Notable logs: Phoenix started with Bandit HTTPS on `0.0.0.0:4000`; Next.js reached `Ready in 8.4s`; Vite reached ready state on `5173` but logged `WebSocket server error: listen EADDRNOTAVAIL: address not available <csb-edge-ip>:443` when `VITE_HMR_HOST` was set to the public preview hostname.
- HMR bind fix: pushed commit `73125ed47a63d13806a97d7c325d21547c09f9aa` changes `libs/client/vite.config.ts` to use Vite `hmr.clientPort` instead of `hmr.port` so the browser can use `443` without asking Vite to bind to the CodeSandbox public edge address. Local `make build-lib` passed, and a pushed-branch CodeSandbox boot probe verified the Vite log no longer contains `WebSocket server error` or `EADDRNOTAVAIL`.
- Process restart/kill observation: pending. The probe started and observed processes, but did not exercise restart/kill semantics.
- Cleanup observation: delete needed retry. Attempt 1 returned `Failed to delete VM pk2c9p: An unexpected error occurred`; attempt 2 succeeded.
- Retest cleanup observation: rerun sandbox `gz2ksm` failed all five inline delete attempts, then a separate SDK delete attempt from `scripts/spikes/` succeeded. Treat delete as flaky and require retry/backoff plus orphan cleanup monitoring.
- Pushed-fix retest: sandbox `8x77sk` cloned `sandboxing_v2` at `73125ed47a63d13806a97d7c325d21547c09f9aa`, opened required ports `4000`, `5173`, and `3000`, and showed a clean Vite startup log with no HMR bind error. Optional Marketing/Astro `4321` still timed out. Inline delete failed five times; explicit orphan cleanup was attempted but blocked because 1Password authorization timed out/dismissed before the CodeSandbox API key could be read.
- Result: pass for runtime-first required boot on Micro. Remaining boot-related work is preview/browser validation, HMR/WebSocket validation, optional Marketing/Astro diagnosis, and lifecycle semantics.

Relevant SDK evidence from docs:

- `client.commands.runBackground(command, {name})` can start long-running commands and expose output via `cmd.open()`, `cmd.onOutput(...)`, and `cmd.waitUntilComplete()`.
- Background commands can be killed or restarted through SDK command handles.
- Docs recommend evaluating CodeSandbox tasks for long-running processes; spike should compare tasks versus explicit background commands.

## Experiment E: Preview, HMR, And WebSockets

Goal: prove the hosted app preview is usable for Frontman.

- Automation URL output: pending
- Preview URL shape: `https://<sandbox-id>-<port>.csb.app?preview_token=<redacted>` for private sandboxes.
- Host token URL/cookie behavior: pending
- iframe embedding behavior: pending
- Provider warning/interstitial: pending
- Phoenix WebSocket result: pending
- Vite/Next HMR result: partial. Vite server-side HMR bind is fixed on `sandboxing_v2` commit `73125ed47a63d13806a97d7c325d21547c09f9aa`; browser-level HMR connection behavior still needs validation through an actual preview session.
- Required host/origin config: Phoenix accepted `PHX_HOST=<sandbox-id>-4000.csb.app` and `PHX_URL_PORT=443`; Vite/Next preview URL config still needs browser validation.
- Result: pending

Relevant SDK evidence from docs:

- Host URL shapes are documented as HTTP/HTTPS `https://$SANDBOX_ID-$PORT.csb.app` and WebSocket `ws://$SANDBOX_ID-$PORT.csb.app`.
- Private sandbox access uses host tokens; opening a signed URL sets a preview token cookie for later browser requests.
- CodeSandbox recommends proxying private hosts through the product backend for lifecycle and access control.
- Proxy docs mention setting `csb_is_trusted=true` when proxying to CodeSandbox hosts.

## Experiment F: Filesystem And Sidecar Feasibility

Goal: decide whether provider APIs are enough for first file-tool semantics or a sidecar is required.

- Read/list/write API support: pending
- File API latency: pending
- Root/path constraints: pending
- Watch support: pending
- Command output shape for `git status`/`git diff`: pending
- Result: pending

Relevant SDK evidence from docs:

- `client.fs` operations are relative to `/project/workspace`.
- Supported operations include `writeTextFile`, `readTextFile`, binary read/write, `batchWrite`, `download`, `readdir`, `copy`, `rename`, `remove`, and recursive `watch` with excludes.
- CodeSandbox persists `/project/workspace` via git snapshots during hibernate/shutdown, so the spike should clone `frontman` as a subdirectory or replace the default remote before normal git commands.

## Experiment G: Lifecycle And Cleanup

Goal: understand what Frontman must own for workspace lifecycle.

- Hibernate/suspend behavior: pending
- Resume behavior: pending
- Restart behavior: pending
- Preview URL stability: pending
- Host token stability: pending
- Delete semantics: partial. SDK delete has repeatedly failed on first attempt for multiple sandboxes, but retry/backoff has succeeded so far.
- Billable resource verification: pending
- Result: pending

## Cost Notes

- Pico: `$0.0743/hr`, 2 cores, 1 GB RAM.
- Nano: `$0.1486/hr`, 2 cores, 4 GB RAM.
- Micro: `$0.2972/hr`, 4 cores, 8 GB RAM.
- Small: `$0.5944/hr`, 8 cores, 16 GB RAM.
- Medium: `$1.1888/hr`, 16 cores, 32 GB RAM.
- Large: `$2.3776/hr`, 32 cores, 64 GB RAM.
- XLarge: `$4.7552/hr`, 64 cores, 128 GB RAM.
- Smallest viable tier: Micro for the full `frontman` dogfood stack so far. `Small` is currently unavailable to this workspace/account; Pico/Nano have not been tested and are unlikely given setup memory/disk observations.
- Active workspace-hour estimate: Micro is `$0.2972/hr`, about `$2.38` per 8-hour active dogfood day per workspace before any hibernation/idle effects.
- Idle/suspended cost: pending; docs recommend manual lifecycle management and hibernation timeout up to `86400` seconds.

## Blockers

- Browser-level preview, Phoenix WebSocket, and HMR validation are still pending.
- Optional Marketing/Astro port `4321` did not open in the full-stack boot probe.
- Lifecycle delete is flaky and requires retry/backoff.
- Sandbox `8x77sk` may still need orphan cleanup once 1Password authorization is available again.

## Recommendation

Continue CodeSandbox evaluation, but adjust the spike shape before adding more Frontman-specific automation.

The next step should be a spike-level `WorkspaceBootPlan` plus a CodeSandbox runner that consumes that plan and returns normalized provider output. The runner can remain disposable, but the contract it validates should resemble the future `WorkspaceProvider` boundary.

Do not keep expanding one-off Frontman-only scripts as the primary proof path. Frontman should be represented as one hard boot plan. Add a second small fixture boot plan to prove the runner is not purely bespoke.

Options:

- Proceed with CodeSandbox SDK
- Retry with template/boot changes
- Reject or pause CodeSandbox SDK
