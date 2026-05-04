# Daytona SDK Provider Spike Report

## Status

- Provider: Daytona
- Scope: `frontman` repo, existing branch, runtime-first validation
- Current recommendation: first alternative to spike after CodeSandbox Micro blocker
- Current branch to test: `sandboxing_v2`
- API credential source: `DAYTONA_API_KEY` environment variable
- Manifest/config path: `scripts/spikes/daytona-frontman-workspace.json`
- Minimal smoke script: `scripts/spikes/daytona-smoke.mjs`
- Marketing preview script: `scripts/spikes/daytona-marketing-preview.mjs`

## Decision Gate Summary

| Gate | Result | Evidence |
|---|---|---|
| SDK can create/delete sandbox | Pending | Run `DAYTONA_API_KEY=... node daytona-smoke.mjs`. |
| Sandbox can expose browser preview URL | Pending | Smoke script starts `python3 -m http.server` on port `3000` and fetches a signed preview URL. |
| Marketing site can boot remotely | Pending | Run `DAYTONA_API_KEY=... node daytona-marketing-preview.mjs --branch <branch>`. |
| Private preview behavior understood | Docs pass | Daytona supports standard preview tokens via `x-daytona-preview-token` and signed preview URLs embedded in the URL. |
| Template/snapshot path supports required runtimes | Pending | Need Docker-in-Docker snapshot from `.devcontainer/Dockerfile` or equivalent custom Dockerfile. |
| Repo clone and branch checkout works | Docs pass, runtime pending | `sandbox.git.clone(url, path, branch, commit, username, password)` supports private repos and branches. |
| Dependencies install and database migrates | Pending | Requires Docker-in-Docker snapshot and real Frontman setup run. |
| Full stack boots | Pending | |
| Phoenix, Vite, and Next.js run simultaneously | Pending | |
| Logs are retrievable without provider UI | Docs pass, runtime pending | Daytona process sessions expose command logs and stream stdout/stderr over SDK/WebSocket. |
| Preview, WebSockets, and HMR work or fallback is acceptable | Pending | Need iframe/browser validation; warning page may require proxy/header/Tier 3. |
| Secrets/env injection path is safe enough for dogfood | Pending | SDK command env and sandbox env vars exist; persistence behavior needs validation. |
| Destroy/recreate is reliable | Pending | Smoke script deletes sandbox in `finally`; later spike should verify `daytona.list()`. |
| Cost is acceptable for internal dogfood | Initial pass | Pricing is usage-based by vCPU, GiB memory, and GiB storage, with `$200` free compute advertised. |

## Account And Access

- Required environment: `DAYTONA_API_KEY`.
- Optional environment: `DAYTONA_API_URL`, `DAYTONA_TARGET`.
- Default sandbox resources: 1 vCPU, 1 GiB RAM, 3 GiB disk.
- Documented standard organization max: 4 vCPU, 8 GiB RAM, 10 GiB disk.
- Larger resources require support or account limit increase.
- Preview port range: HTTP ports `3000` through `9999`.

## Runtime Requirements Observed In Repo

- Tool versions: Node `24.9.0`, Yarn `4.10.3`, Elixir `1.19.3-otp-28`, Erlang `28.1.1`, `mprocs` `0.7.1`, `mkcert` `1.4.4` from `mise.toml`.
- Devcontainer/template source: `.devcontainer/Dockerfile` based on Ubuntu `24.04`; installs build tooling, git/curl/wget/unzip, SSL libraries, inotify, Postgres client, Erlang/Elixir native deps, mkcert deps, jq, sudo, locales, and `mise`.
- Required services: Phoenix `4000`, Vite `5173`, Next.js `3000`, Marketing/Astro `4321` optional, Storybook `6006` optional.
- Postgres approach: Daytona must prove Docker-in-Docker plus `docker compose up -d db`, or use a non-Docker Postgres process in the sandbox.
- Local routing assumptions: `mprocs.container.yml` uses `*.frontman.local`; Daytona needs provider preview URLs or a provider-aware env mapping.
- Server secret behavior: local dev uses `op run`; Daytona needs explicit env injection from Frontman, not 1Password inside the sandbox.

## Experiment A: Minimal SDK Smoke Test

Goal: prove SDK create/command/session/preview/delete before touching Frontman.

Command:

```bash
DAYTONA_API_KEY="..." node "daytona-smoke.mjs"
```

Expected behavior:

- Creates an ephemeral Daytona sandbox from `Image.debianSlim("3.12")`.
- Uses resources from `DAYTONA_CPU`, `DAYTONA_MEMORY_GIB`, and `DAYTONA_DISK_GIB`, defaulting to `2/4/8`.
- Runs `python3 --version`.
- Creates a process session and starts `python3 -m http.server 3000 --bind 0.0.0.0` asynchronously.
- Creates a signed preview URL for port `3000` with a one-hour expiry.
- Fetches the signed preview URL.
- Deletes the sandbox in `finally`.

Result: pending.

Relevant SDK evidence from docs:

- `new Daytona()` reads `DAYTONA_API_KEY`, `DAYTONA_API_URL`, and `DAYTONA_TARGET`.
- `daytona.create({image, resources, ephemeral, autoStopInterval})` creates a sandbox.
- `sandbox.process.executeCommand(command, cwd, env, timeout)` executes shell commands.
- `sandbox.process.createSession(sessionId)` and `sandbox.process.executeSessionCommand(sessionId, {command, runAsync: true})` support long-running commands.
- `sandbox.getSignedPreviewUrl(port, expiresInSeconds)` returns a browser-usable preview URL.
- `sandbox.delete()` deletes the sandbox.

## Experiment A2: Marketing Preview Slice

Goal: prove a narrow Frontman repo clone can run `apps/marketing` remotely and return a browser-usable Daytona preview URL before attempting Phoenix/Postgres/full-stack boot.

Command:

```bash
DAYTONA_API_KEY="..." GITHUB_TOKEN="..." node "daytona-marketing-preview.mjs" --branch spike/codesandbox-work
```

Expected behavior:

- Creates a Daytona sandbox from `node:22-bookworm` with Git installed.
- Uses `4 vCPU / 8 GiB RAM / 10 GiB disk` by default to stay within documented standard org limits.
- Clones `https://github.com/frontman-ai/frontman.git` branch passed by `--branch` into `workspace/frontman`.
- Patches `apps/marketing/astro.config.mjs` inside the sandbox clone only so Vite accepts provider preview hostnames.
- Runs `corepack enable && yarn install --immutable`.
- Runs `yarn workspace @frontman-ai/astro build` to satisfy the marketing site's workspace dependency.
- Starts `yarn workspace marketing dev --host 0.0.0.0 --port 4321` in a Daytona process session.
- Creates a signed preview URL and probes `/`, `/docs/`, and `/frontman/tools`.
- Keeps the sandbox alive by default for browser/manual Frontman verification; pass `--delete` for throwaway runs.

Result: pending.

## Experiment B: Frontman Snapshot Or Devcontainer Boot

Goal: determine whether Daytona can reuse the existing Frontman devcontainer or needs a Daytona-specific Docker-in-Docker snapshot.

Recommended first pass:

```bash
daytona snapshot create frontman-daytona-dind --dockerfile ../../.devcontainer/Dockerfile --cpu 4 --memory 8 --disk 10
```

Open questions:

- Does the existing devcontainer Dockerfile need Docker-in-Docker setup added, or should the Daytona snapshot start from `docker:28.3.3-dind` and install Frontman dependencies on top?
- Does Daytona validate and run Ubuntu + non-root `vscode` snapshots exactly as expected?
- Is 10 GiB disk enough after clone, `mise install`, `yarn install`, Postgres image pull, and build artifacts?
- Can support raise disk to 20-30 GiB for a fair comparison against CodeSandbox Micro's 30 GiB workspace?

Result: pending.

Relevant docs evidence:

- Snapshots can be built from Docker/OCI images, local Dockerfiles, or registry images.
- Docker-in-Docker is supported, and Daytona recommends at least 2 vCPU and 4 GiB memory.
- Default snapshots include Python/Node tooling but not Frontman's full stack or Docker Compose proof.

## Experiment C: Frontman Repo Clone And Setup

Goal: clone `frontman`, install toolchain/deps, run ReScript, and migrate the database.

Proposed setup sequence is captured in `daytona-frontman-workspace.json`.

Credential handling:

- Use `GITHUB_TOKEN` from the host process, passed only to the SDK Git clone call.
- Do not write token to sandbox files.
- Prefer Daytona `sandbox.git.clone(repo, workdir, branch, undefined, "git", token)` over shell `GIT_ASKPASS` for first pass.

Checks:

- `git status --short --branch && git rev-parse HEAD && git remote -v`
- `mise trust --all && mise install --yes`
- `mise exec -- node --version && mise exec -- yarn --version && mise exec -- elixir --version && mise exec -- erl -eval 'erlang:display(erlang:system_info(otp_release)), halt().' -noshell && mise exec -- mprocs --version`
- `docker compose up -d db`
- `pg_isready -h localhost -U postgres`
- `mise exec -- yarn install`
- `mise exec -- yarn rescript build`
- `cd apps/frontman_server && mix local.hex --force && mix local.rebar --force && mix deps.get && mix ecto.create || true && mix ecto.migrate`

Result: pending.

## Experiment D: Full Stack Boot

Goal: boot Phoenix, Vite, Next.js, and optional Marketing/Storybook with retrievable logs.

Proposed process model:

- One Daytona process session per long-running process in `daytona-frontman-workspace.json`.
- Use `executeSessionCommand(..., {runAsync: true})` for each process.
- Stream command logs with `getSessionCommandLogs`.
- Stop/delete sessions during cleanup.

Result: pending.

## Experiment E: Preview, HMR, And WebSockets

Goal: prove the hosted app preview is usable inside Frontman.

Preview candidates:

- Standard preview URL plus `x-daytona-preview-token` header for server-side proxy checks.
- Signed preview URL for browser/iframe checks.
- Frontman-owned proxy that sets `X-Daytona-Skip-Preview-Warning: true` if Daytona warning page blocks embedding.

Risks:

- Daytona browser warning page appears on first browser visit unless the skip header is sent, the account is Tier 3, or we deploy a custom preview proxy.
- Standard preview tokens reset on sandbox restart.
- Signed preview tokens persist until expiry/revocation but max at 24 hours.

Result: pending.

### Experiment E1: Throwaway Frontman Preview Proxy

Goal: route Daytona preview traffic through Frontman so browser requests do not see Daytona tokens or warning pages.

Dev-only server route:

```text
/_spikes/daytona-preview/*path
```

Runtime config:

```bash
DAYTONA_PREVIEW_URL="https://4321-...daytonaproxy01.eu"
DAYTONA_PREVIEW_TOKEN="..." # only needed for standard preview URLs
```

Behavior:

- Forwards arbitrary methods to `DAYTONA_PREVIEW_URL` with the original path and query string.
- Sends `X-Daytona-Skip-Preview-Warning: true`.
- Sends `X-Forwarded-Host` with the incoming Frontman host.
- Sends `X-Daytona-Preview-Token` when `DAYTONA_PREVIEW_TOKEN` is configured.
- Intentionally skips router pipelines so CSRF/auth requirements do not block proxied preview methods.
- Re-encodes already-parsed JSON params because Phoenix endpoint parsers still run before routing.

Known limitation:

- This first throwaway route proxies regular HTTP only; WebSocket upgrade support still needs a separate slice if HMR requires it through Frontman.

## Experiment F: Filesystem And Sidecar Feasibility

Goal: decide whether Daytona file/Git/process APIs are enough for first file-tool semantics.

Relevant SDK evidence:

- `sandbox.fs.listFiles(path)` lists directory entries.
- `sandbox.fs.downloadFile(path)` reads files.
- `sandbox.fs.uploadFile(buffer, path)` writes files.
- `sandbox.fs.findFiles({path, pattern})` searches file content.
- `sandbox.fs.replaceInFiles(files, pattern, newValue)` performs replacements.
- `sandbox.git.status`, `branches`, `add`, `commit`, `push`, and `pull` exist.

Result: pending.

## Experiment G: Lifecycle And Cleanup

Goal: understand what Frontman must own for workspace lifecycle and cost control.

Relevant docs evidence:

- `sandbox.stop()` preserves filesystem and clears memory; stopped sandboxes incur disk cost.
- `sandbox.archive()` moves stopped filesystem state to object storage.
- `sandbox.delete()` removes the sandbox.
- `ephemeral: true` deletes the sandbox after stop.
- `autoStopInterval` defaults to 15 minutes; long-running background processes do not count as activity.
- `autoDeleteInterval: 0` deletes immediately after stop; `-1` disables auto-delete.

Result: pending.

## Cost Notes

- vCPU: `$0.0504/h`.
- Memory: `$0.0162/GiB/h`.
- Storage: `$0.000108/GiB/h` after first 5 GiB free.
- 4 vCPU / 8 GiB / 10 GiB active estimate: about `$0.3324/h` plus storage beyond included free amount.
- Daytona advertises `$200` free compute and startup credits up to `$50k`.

## Blockers

- Need a Daytona API key and org resource limit check.
- Need to decide whether to create a Docker-in-Docker snapshot from current `.devcontainer/Dockerfile` or a new Daytona-specific Dockerfile.
- Need disk limit validation; 10 GiB may be tight for the cold Frontman setup.
- Need browser/iframe preview validation because Daytona warning page is a product integration risk.

## Recommendation

Run the Daytona smoke first. If it passes, build a Docker-in-Docker snapshot and run the Frontman clone/setup experiment. If disk or Docker-in-Docker fails at the default org limit, ask Daytona for a larger sandbox limit before rejecting the provider; otherwise we'd be rejecting a probably-good provider for an account-limit faceplant, which is a very stupid way to do science.
