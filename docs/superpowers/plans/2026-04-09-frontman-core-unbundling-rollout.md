# Frontman Core Unbundling Rollout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship the frontman-core unbundling refactor safely by verifying publishability, adding changesets, and adding a CI smoke test that catches broken npm installs before they reach clients.

**Architecture:** Three packages that were never published to npm (`@frontman-ai/frontman-protocol`, `@frontman/bindings`, `@frontman-ai/frontman-core`) must be published before the updated framework packages. A pack-and-install smoke test added to CI exercises the real npm resolution path that the workspace-based e2e tests cannot cover.

**Tech Stack:** yarn workspaces (berry), changesets, npm, GitHub Actions CI

---

## File Map

| File | Action | Purpose |
|---|---|---|
| `.changeset/unbundle-dep-packages.md` | Create | Changeset for protocol, bindings, core (first publish) |
| `.changeset/unbundle-framework-packages.md` | Create | Changeset for astro, vite, nextjs (minor bump) |
| `scripts/smoke-test-publish.sh` | Create | Local pack-and-install smoke test script |
| `.github/workflows/ci.yml` | Modify | Add `publish-smoke-test` job |

---

## Task 1: Verify dry-run pack output for dep packages

**Files:** No changes — verification only.

- [ ] **Step 1: Pack @frontman-ai/frontman-protocol (dry run)**

```bash
yarn workspace @frontman-ai/frontman-protocol pack --dry-run 2>&1
```

Expected output: a list of files including `src/FrontmanProtocol.res.mjs`, `src/**/*.res.mjs`, and `schemas/**`. If you see an empty list or only `package.json`, stop — the `files` field in `libs/frontman-protocol/package.json` is wrong.

- [ ] **Step 2: Pack @frontman/bindings (dry run)**

```bash
yarn workspace @frontman/bindings pack --dry-run 2>&1
```

Expected output: files including `src/Lighthouse.res.mjs`, `src/ChromeLauncher.res.mjs`, and other `.res.mjs` files in `src/`. If the `.res.mjs` files are missing, run `yarn rescript build` in `libs/bindings/` first — the files are compiled in-source and must exist before packing.

- [ ] **Step 3: Pack @frontman-ai/frontman-core (dry run)**

```bash
yarn workspace @frontman-ai/frontman-core pack --dry-run 2>&1
```

Expected output: files including `src/FrontmanCore.res.mjs` and other `.res.mjs` files under `src/`. Same caveat: run `yarn rescript build` in `libs/frontman-core/` if the compiled files are missing.

- [ ] **Step 4: No commit needed** — verification only.

---

## Task 2: Create changesets for the three dep packages (first publish)

**Files:**
- Create: `.changeset/unbundle-dep-packages.md`

These are first-time npm publishes. Use `patch` — there is no prior published version to compare against, so major/minor/patch distinctions are moot; patch is conventional for inaugural packages.

- [ ] **Step 1: Create the changeset file**

Create `.changeset/unbundle-dep-packages.md` with this exact content:

```markdown
---
"@frontman-ai/frontman-protocol": patch
"@frontman/bindings": patch
"@frontman-ai/frontman-core": patch
---

First npm publish of @frontman-ai/frontman-protocol, @frontman/bindings, and
@frontman-ai/frontman-core as standalone packages. Previously these were bundled
inside the framework wrappers (astro, vite, nextjs). They are now declared as
explicit dependencies and installed by the client's package manager.
```

- [ ] **Step 2: Verify the changeset is valid**

```bash
yarn changeset status 2>&1
```

Expected: shows the three packages with a patch bump. No errors.

- [ ] **Step 3: Commit**

```bash
git add .changeset/unbundle-dep-packages.md
git commit -m "chore: add changeset for first publish of dep packages"
```

---

## Task 3: Create changeset for the three framework packages

**Files:**
- Create: `.changeset/unbundle-framework-packages.md`

Use `minor` — the dep graph changes visibly in consumers' lockfiles and `node_modules`. This is correct for 0.x where minor signals "something meaningful changed."

- [ ] **Step 1: Create the changeset file**

Create `.changeset/unbundle-framework-packages.md` with this exact content:

```markdown
---
"@frontman-ai/astro": minor
"@frontman-ai/vite": minor
"@frontman-ai/nextjs": minor
---

Stop bundling @frontman-ai/frontman-core into framework wrappers. The core
package and its dependencies (@frontman-ai/frontman-protocol, @frontman/bindings,
@rescript/runtime, sury, dom-element-to-component-source) are now declared as
explicit dependencies and installed by your package manager automatically.

No migration required — upgrade as normal.
```

- [ ] **Step 2: Verify the changeset is valid**

```bash
yarn changeset status 2>&1
```

Expected: now shows six packages total — three patch (dep packages) and three minor (framework packages). No errors.

- [ ] **Step 3: Commit**

```bash
git add .changeset/unbundle-framework-packages.md
git commit -m "chore: add changeset for framework package minor bump"
```

---

## Task 4: Write the pack-and-install smoke test script

**Files:**
- Create: `scripts/smoke-test-publish.sh`

This script builds all six packages, packs them to tarballs, then installs them into a clean temp directory using `file://` references (so npm resolves the local tarballs instead of trying npm registry, which would 404 for the three unpublished packages). It then imports the entry point to verify there are no missing-dependency errors at load time.

- [ ] **Step 1: Write the script**

Create `scripts/smoke-test-publish.sh`:

```bash
#!/usr/bin/env bash
# Pack-and-install smoke test for npm publishability.
#
# Builds all six packages, packs them to tarballs, then installs them into a
# clean temp directory. Uses file:// references for the three packages not yet
# on npm (protocol, bindings, core) so npm resolves the local tarballs rather
# than hitting the registry.
#
# Run from the repo root: bash scripts/smoke-test-publish.sh

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMPDIR="$(mktemp -d)"
trap 'rm -rf "$TMPDIR"' EXIT

echo "→ Building dep packages..."
(cd "$ROOT/libs/frontman-protocol" && yarn rescript build)
(cd "$ROOT/libs/bindings" && yarn rescript build)
(cd "$ROOT/libs/frontman-core" && yarn rescript build)

echo "→ Building framework packages..."
(cd "$ROOT/libs/frontman-astro" && yarn build)
(cd "$ROOT/libs/frontman-vite" && yarn build)
(cd "$ROOT/libs/frontman-nextjs" && yarn build)

echo "→ Packing all packages..."
(cd "$ROOT" && yarn workspace @frontman-ai/frontman-protocol pack --out "$TMPDIR/frontman-protocol.tgz")
(cd "$ROOT" && yarn workspace @frontman/bindings pack --out "$TMPDIR/frontman-bindings.tgz")
(cd "$ROOT" && yarn workspace @frontman-ai/frontman-core pack --out "$TMPDIR/frontman-core.tgz")
(cd "$ROOT" && yarn workspace @frontman-ai/astro pack --out "$TMPDIR/frontman-astro.tgz")
(cd "$ROOT" && yarn workspace @frontman-ai/vite pack --out "$TMPDIR/frontman-vite.tgz")
(cd "$ROOT" && yarn workspace @frontman-ai/nextjs pack --out "$TMPDIR/frontman-nextjs.tgz")

echo "→ Verifying tarballs are non-empty..."
for tgz in "$TMPDIR"/*.tgz; do
  SIZE=$(wc -c < "$tgz")
  if [ "$SIZE" -lt 1000 ]; then
    echo "ERROR: $tgz is suspiciously small ($SIZE bytes) — build may have failed"
    exit 1
  fi
  echo "  ✓ $(basename "$tgz") (${SIZE} bytes)"
done

echo "→ Testing clean install of @frontman-ai/astro..."
TESTDIR="$TMPDIR/test-astro"
mkdir -p "$TESTDIR"
cat > "$TESTDIR/package.json" << EOF
{
  "name": "smoke-test-astro",
  "type": "module",
  "dependencies": {
    "@frontman-ai/astro": "file:$TMPDIR/frontman-astro.tgz",
    "@frontman-ai/frontman-core": "file:$TMPDIR/frontman-core.tgz",
    "@frontman-ai/frontman-protocol": "file:$TMPDIR/frontman-protocol.tgz",
    "@frontman/bindings": "file:$TMPDIR/frontman-bindings.tgz",
    "astro": "^5.0.0"
  }
}
EOF
npm install --prefix "$TESTDIR" --silent
echo "import mod from '@frontman-ai/astro'; console.log('✓ @frontman-ai/astro loaded, type:', typeof mod);" > "$TESTDIR/check.mjs"
node "$TESTDIR/check.mjs"

echo "→ Testing clean install of @frontman-ai/vite..."
TESTDIR="$TMPDIR/test-vite"
mkdir -p "$TESTDIR"
cat > "$TESTDIR/package.json" << EOF
{
  "name": "smoke-test-vite",
  "type": "module",
  "dependencies": {
    "@frontman-ai/vite": "file:$TMPDIR/frontman-vite.tgz",
    "@frontman-ai/frontman-core": "file:$TMPDIR/frontman-core.tgz",
    "@frontman-ai/frontman-protocol": "file:$TMPDIR/frontman-protocol.tgz",
    "@frontman/bindings": "file:$TMPDIR/frontman-bindings.tgz",
    "vite": "^6.0.0"
  }
}
EOF
npm install --prefix "$TESTDIR" --silent
echo "import mod from '@frontman-ai/vite'; console.log('✓ @frontman-ai/vite loaded, type:', typeof mod);" > "$TESTDIR/check.mjs"
node "$TESTDIR/check.mjs"

echo "→ Testing clean install of @frontman-ai/nextjs..."
TESTDIR="$TMPDIR/test-nextjs"
mkdir -p "$TESTDIR"
cat > "$TESTDIR/package.json" << EOF
{
  "name": "smoke-test-nextjs",
  "type": "module",
  "dependencies": {
    "@frontman-ai/nextjs": "file:$TMPDIR/frontman-nextjs.tgz",
    "@frontman-ai/frontman-core": "file:$TMPDIR/frontman-core.tgz",
    "@frontman-ai/frontman-protocol": "file:$TMPDIR/frontman-protocol.tgz",
    "@frontman/bindings": "file:$TMPDIR/frontman-bindings.tgz",
    "next": "~15.0.0",
    "react": "^19.0.0",
    "react-dom": "^19.0.0"
  }
}
EOF
npm install --prefix "$TESTDIR" --silent
echo "import mod from '@frontman-ai/nextjs'; console.log('✓ @frontman-ai/nextjs loaded, type:', typeof mod);" > "$TESTDIR/check.mjs"
node "$TESTDIR/check.mjs"

echo ""
echo "✓ All smoke tests passed"
```

- [ ] **Step 2: Make it executable**

```bash
chmod +x scripts/smoke-test-publish.sh
```

- [ ] **Step 3: Run the smoke test locally**

```bash
bash scripts/smoke-test-publish.sh
```

Expected output (last few lines):
```
✓ @frontman-ai/astro loaded, type: function
✓ @frontman-ai/vite loaded, type: function
✓ @frontman-ai/nextjs loaded, type: function

✓ All smoke tests passed
```

If any step fails:
- "suspiciously small" tarball → the rescript build or tsup step didn't run; check the build output
- npm 404 error → a dep package name in the test `package.json` is wrong; check the `name` field in its `package.json`
- `Cannot find package` at import → the package's `exports` map is wrong; check `libs/<pkg>/package.json`
- Import throws at load time (not a resolution error) → the package has init-time side effects; replace `import mod from '...'` with `import('...').then(() => ...)` and catch — you're testing resolution, not runtime behavior

- [ ] **Step 4: Commit**

```bash
git add scripts/smoke-test-publish.sh
git commit -m "test: add pack-and-install smoke test script for npm publishability"
```

---

## Task 5: Add the smoke test job to CI

**Files:**
- Modify: `.github/workflows/ci.yml`

Add a new `publish-smoke-test` job to ci.yml. It follows the same checkout/setup-node/corepack/install pattern as the existing jobs, then runs the smoke test script.

- [ ] **Step 1: Add the job to ci.yml**

Open `.github/workflows/ci.yml`. Find the last job in the file (before the closing of the `jobs:` block). Add the following new job after it:

```yaml
  publish-smoke-test:
    name: Publish smoke test
    runs-on: ubuntu-latest
    steps:
      - name: Checkout code
        uses: actions/checkout@de0fac2e4500dabe0009e67214ff5f5447ce83dd # v6.0.2

      - name: Setup Node.js
        uses: actions/setup-node@6044e13b5dc448c55e2357c09f80417699197238 # v6.2.0
        with:
          node-version: '24.4.1'

      - name: Enable Corepack
        run: corepack enable

      - name: Cache dependencies
        uses: actions/cache@cdf6c1fa76f9f475f3d7449005a359c84ca0f306 # v5.0.3
        with:
          path: |
            ~/.yarn/berry/cache
            node_modules
          key: deps-${{ runner.os }}-${{ hashFiles('yarn.lock') }}
          restore-keys: deps-${{ runner.os }}-

      - name: Install dependencies
        run: yarn install --immutable

      - name: Run publish smoke test
        run: bash scripts/smoke-test-publish.sh
```

- [ ] **Step 2: Verify the YAML is valid**

```bash
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/ci.yml'))" && echo "YAML valid"
```

Expected: `YAML valid`

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: add publish smoke test job to verify npm installability"
```

---

## Task 6: Final verification and PR prep

- [ ] **Step 1: Verify all changesets are present**

```bash
yarn changeset status 2>&1
```

Expected: 6 packages listed — `@frontman-ai/frontman-protocol` (patch), `@frontman/bindings` (patch), `@frontman-ai/frontman-core` (patch), `@frontman-ai/astro` (minor), `@frontman-ai/vite` (minor), `@frontman-ai/nextjs` (minor).

- [ ] **Step 2: Run the smoke test one final time from a clean state**

```bash
bash scripts/smoke-test-publish.sh
```

Expected: `✓ All smoke tests passed`

- [ ] **Step 3: Check git log looks right**

```bash
git log --oneline origin/main..HEAD
```

Expected commits (order may vary):
```
ci: add publish smoke test job to verify npm installability
test: add pack-and-install smoke test script for npm publishability
chore: add changeset for framework package minor bump
chore: add changeset for first publish of dep packages
docs: add rollout design spec for frontman-core unbundling
```

- [ ] **Step 4: Push and open PR**

```bash
make push
```

(`make push` pushes and auto-posts the AGD usage summary as a PR comment, per the project workflow.)

---

## Post-merge release steps (manual, not automated)

These happen after the PR is merged to `main`:

1. **Create the release PR:**
   ```bash
   make release
   ```
   Watch for the release PR at https://github.com/frontman-ai/frontman/pulls. Review the CHANGELOG, then merge.

2. **Publish to npm** (run after the release PR is merged):
   ```bash
   make publish OTP=<your-2fa-code>
   ```
   The `publish` target publishes in the correct order: protocol → bindings → core → astro → vite → nextjs → react-statestore. Each step guards against double-publishing.

3. **Verify the publish succeeded:**
   ```bash
   npm view @frontman-ai/frontman-core version
   npm view @frontman/bindings version
   npm view @frontman-ai/frontman-protocol version
   ```
   All three should return the versions from their `package.json` (currently `0.5.5`, `0.3.1`, `0.6.0`).
