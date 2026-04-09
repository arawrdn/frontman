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
echo "import * as mod from '@frontman-ai/vite'; console.log('✓ @frontman-ai/vite loaded, exports:', Object.keys(mod).join(', '));" > "$TESTDIR/check.mjs"
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
echo "import * as mod from '@frontman-ai/nextjs'; console.log('✓ @frontman-ai/nextjs loaded, exports:', Object.keys(mod).join(', '));" > "$TESTDIR/check.mjs"
node "$TESTDIR/check.mjs"

echo ""
echo "✓ All smoke tests passed"
