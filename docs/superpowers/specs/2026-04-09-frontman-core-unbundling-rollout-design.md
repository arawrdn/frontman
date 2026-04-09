# Rollout Design: Stop Bundling frontman-core

**Date:** 2026-04-09
**Branch:** issue-419-refactor-stop-bundling-frontmancore

## Context

PR #419 changes how `@frontman-ai/frontman-core` (and its siblings) are distributed. Previously, each framework wrapper (`@frontman-ai/astro`, `@frontman-ai/vite`, `@frontman-ai/nextjs`) bundled frontman-core and its transitive deps into their tsup output. After this PR, those packages are declared as regular `dependencies` and resolved by the client's package manager at install time.

**Client impact:** Zero — clients always install framework wrappers, never `frontman-core` directly. npm/yarn auto-installs the new dep tree on upgrade. No API or config changes.

## The Blocker

Three packages newly declared as dependencies in the framework wrappers **do not exist on npm**:

| Package | Local version | npm status |
|---|---|---|
| `@frontman-ai/frontman-protocol` | 0.6.0 | 404 |
| `@frontman/bindings` | 0.3.1 | 404 |
| `@frontman-ai/frontman-core` | 0.5.5 | 404 |

If the updated framework packages are published before these three, any client running `npm install @frontman-ai/astro@latest` gets a hard 404. The framework packages must not be published until all three deps are live on npm.

All other declared deps (`@rescript/runtime@12.0.0-beta.14`, `dom-element-to-component-source@0.5.0`, `sury@11.0.0-alpha.4`) already exist on npm.

## E2E Test Gap

All e2e fixtures use `workspace:*` for the framework packages, meaning yarn's workspace resolution fills in all deps from the monorepo automatically. The e2e tests validate integration behavior but **cannot detect a broken npm package manifest** (missing dep, wrong version, unpublished dep). Only a real `npm install` from the registry exercises this path.

## Design

### Phase 1 — Verify publishability (light)

Run `yarn pack --dry-run` on each of the three new packages and confirm the tarball contains the expected `.res.mjs` files. All three use `"in-source": true` in their `rescript.json`, so compiled output lands in `src/` — the `"files": ["src"]` field in each `package.json` is correct. No fixes expected; this is a sanity check only.

### Phase 2 — Changesets

Add changesets for all six affected packages:

- `@frontman-ai/frontman-protocol` — **patch** (first publish, no semver history)
- `@frontman/bindings` — **patch** (first publish, no semver history)
- `@frontman-ai/frontman-core` — **patch** (first publish, no semver history)
- `@frontman-ai/astro` — **minor** (dep graph change; internal, but potentially visible in lockfiles)
- `@frontman-ai/vite` — **minor**
- `@frontman-ai/nextjs` — **minor**

### Phase 3 — Pack-and-install smoke test (CI)

Add a CI job that validates the real npm install scenario the `workspace:*` e2e tests can't cover:

1. Build all six packages
2. `yarn pack` each framework package to a tarball
3. Create a temp directory with a minimal `package.json` pointing at the tarballs
4. Run `npm install` against the real npm registry (so transitive deps resolve from npm, not workspace)
5. Assert the install succeeds without 404s and that the package entry point can be imported (`node -e "import('@frontman-ai/astro')"` etc.)

This job runs on every PR, not just at release time. It catches manifest issues before they reach clients.

### Phase 4 — Publish sequence

Publishing is manual (`make publish OTP=<code>`). The existing `make publish` target already encodes the correct ordering:

```
publish-deps: publish-protocol → publish-bindings → publish-core
publish: publish-deps → publish-astro → publish-vite → publish-nextjs → publish-react-statestore
```

The per-package `publish` targets guard against double-publishing by checking if the version already exists on npm before proceeding.

**Release steps:**
1. Merge this PR to `main`
2. Run `make release` to trigger the release PR workflow
3. Review and merge the release PR (bumps versions, updates CHANGELOG)
4. Run `make publish OTP=<code>` — deps publish first, framework packages after

## What Is Not in Scope

- Publishing `@frontman-ai/client`, `@frontman-ai/frontman-client` (not dependencies of any framework package)
- Automated npm publish in CI (current manual flow is fine)
- Major version bump (client-facing API is unchanged; minor is appropriate for 0.x)
