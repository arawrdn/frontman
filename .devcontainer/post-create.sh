#!/bin/bash
set -e

# mise is installed in ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

cd /workspaces/frontman

echo "==> Trusting mise config..."
~/.local/bin/mise trust --all

echo "==> Installing runtimes via mise (this may take a while)..."
~/.local/bin/mise install --yes

# Activate mise for current shell and add shims to PATH
eval "$(~/.local/bin/mise activate bash)"
export PATH="$HOME/.local/share/mise/shims:$PATH"

echo "==> Verifying tools..."
which node && node --version
which yarn && yarn --version
which elixir && elixir --version

echo "==> Installing project dependencies..."
yarn install

echo "==> Setup complete!"
echo ""
echo "Available commands:"
echo "  make dev        - Start ReScript compiler"
echo "  make client     - Start Vite client dev server"
echo "  make server     - Start Elixir Phoenix server"
echo "  make dev-nextjs - Start Next.js test site"
echo ""
echo "Database: postgres://postgres:postgres@host.docker.internal:5432/frontman_server_dev"
