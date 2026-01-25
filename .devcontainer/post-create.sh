#!/bin/bash
set -e

# mise is installed in ~/.local/bin
export PATH="$HOME/.local/bin:$PATH"

echo "==> Installing runtimes via mise..."
cd /workspaces/frontman

# Trust the project and install runtimes
~/.local/bin/mise trust
~/.local/bin/mise install

# Activate mise for current shell
eval "$(~/.local/bin/mise activate bash)"

echo "==> Installing project dependencies..."
make install

echo "==> Setup complete!"
echo ""
echo "Available commands:"
echo "  make dev        - Start ReScript compiler"
echo "  make client     - Start Vite client dev server"
echo "  make server     - Start Elixir Phoenix server"
echo "  make dev-nextjs - Start Next.js test site"
echo ""
echo "Database: postgres://postgres:postgres@host.docker.internal:5432/frontman_server_dev"
