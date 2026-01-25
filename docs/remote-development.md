# Remote Development with DevPod

This guide explains how to use DevPod to run Frontman development environments on a remote Hetzner server.

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Hetzner Cloud Server (77.42.16.199)                                    │
│  CX43: 8 vCPU, 16GB RAM, 160GB NVMe                                     │
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐    │
│  │  Caddy Reverse Proxy (ports 80/443)                             │    │
│  │  Routes: wt-{hash}-{service}.local → container IP               │    │
│  └──────────────────────────────┬──────────────────────────────────┘    │
│                                 │                                       │
│  ┌──────────────────────────────┼──────────────────────────────────┐    │
│  │ Docker                       │                                  │    │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │    │
│  │  │ wt-ea0c     │  │ wt-b09b     │  │ wt-xxxx     │  ...         │    │
│  │  │ (issue-164) │  │ (issue-189) │  │ (feature-X) │              │    │
│  │  │ :4000 :5173 │  │ :4000 :5173 │  │ :4000 :5173 │              │    │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │    │
│  └─────────────────────────────────────────────────────────────────┘    │
│  PostgreSQL 16 (shared across workspaces)                               │
└─────────────────────────────────────────────────────────────────────────┘
          ↑
          │ SSH Tunnel (ports 8080→80, 8443→443)
          ↓
┌─────────────────────────────────────────────────────────────────────────┐
│  Your Local Machine                                                     │
│  - /etc/hosts: wt-ea0c-nextjs.local → 127.0.0.1                         │
│  - Browser: https://wt-ea0c-nextjs.local:8443                           │
│  - All services accessible via subdomains                               │
└─────────────────────────────────────────────────────────────────────────┘
```

## URL Scheme

Each worktree gets a unique 4-character hash ID based on its name:

| Worktree | Hash | Next.js URL | Vite URL | Phoenix URL |
|----------|------|-------------|----------|-------------|
| issue-164 | wt-ea0c | https://wt-ea0c-nextjs.local:8443 | https://wt-ea0c-vite.local:8443 | https://wt-ea0c-api.local:8443 |
| issue-189 | wt-b09b | https://wt-b09b-nextjs.local:8443 | https://wt-b09b-vite.local:8443 | https://wt-b09b-api.local:8443 |

Services per worktree:
- `wt-{hash}-nextjs.local` - Next.js dev server (port 3000)
- `wt-{hash}-vite.local` - Vite client dev server (port 5173)
- `wt-{hash}-api.local` - Phoenix server (port 4000)
- `wt-{hash}-storybook.local` - Storybook (port 6006)

## Prerequisites

- SSH key configured (already done if you can `ssh root@77.42.16.199`)
- DevPod CLI installed locally
- mkcert installed locally (`brew install mkcert`)

## Quick Start

```bash
# 1. Add hosts entries (one-time)
make worktree-hosts | sudo tee -a /etc/hosts

# 2. Start SSH tunnel (keep running in a terminal)
make tunnel

# 3. Get URLs for your worktree
make worktree-urls BRANCH=issue-164
```

## Setup

### 1. Install DevPod

```bash
# macOS
brew install devpod

# Linux
curl -L -o devpod "https://github.com/loft-sh/devpod/releases/latest/download/devpod-linux-amd64"
chmod +x devpod
sudo mv devpod /usr/local/bin/

# Verify installation
devpod version
```

### 2. Add Hetzner Server as SSH Provider

```bash
# Add the SSH provider with our Hetzner server
devpod provider add ssh --option HOST=root@77.42.16.199
```

### 3. Create Your First Workspace

```bash
# Create a workspace from the main branch
devpod up github.com/YOUR_ORG/frontman --branch main --id main

# Or from a feature branch
devpod up github.com/YOUR_ORG/frontman --branch feature/my-feature --id my-feature
```

This will:
1. Clone the repo on the remote server
2. Build the devcontainer image
3. Install all runtimes (Node.js, Elixir, etc.) via mise
4. Run `make install` to get dependencies
5. Set up SSH tunneling for all ports

### 4. Connect Your IDE

```bash
# Open in VS Code
devpod up main --ide vscode

# Or use SSH directly
devpod ssh main
```

## Daily Workflow

### Starting Work

```bash
# List available workspaces
devpod list

# Start/connect to a workspace
devpod up my-feature --ide vscode
```

### Inside the Workspace

Once connected, you can run the standard dev commands:

```bash
# Terminal 1: ReScript compiler
make dev

# Terminal 2: Vite client dev server (port 5173)
make dev-client

# Terminal 3: Elixir Phoenix server (port 4000)
make dev-server

# Terminal 4: Next.js test site (port 3000)
make dev-nextjs
```

### Accessing Services via Browser

**On your local machine**, ensure the SSH tunnel is running:

```bash
# In a separate terminal, keep this running
make tunnel
```

Then access services via their subdomains (get URLs with `make worktree-urls BRANCH=your-branch`):

- `https://wt-xxxx-nextjs.local:8443` - Next.js
- `https://wt-xxxx-vite.local:8443` - Vite client
- `https://wt-xxxx-api.local:8443` - Phoenix server
- `https://wt-xxxx-storybook.local:8443` - Storybook

The services are routed through Caddy reverse proxy on the server, which handles SSL termination with locally-trusted certificates.

### Creating New Feature Workspaces

There are two ways to create feature workspaces:

#### Option A: One Command (Recommended)

Use the integrated Makefile command that creates a local worktree, pushes the branch, and sets up DevPod:

```bash
make worktree-devpod BRANCH=issue-164
```

This will:
1. Create a local worktree at `.worktrees/issue-164/`
2. Push the branch to origin
3. Create a DevPod workspace on the remote server
4. Print connection instructions

#### Option B: Manual Steps

If you prefer more control:

```bash
# 1. Create local worktree (optional, for local dev)
make worktree-create BRANCH=issue-164

# 2. Push branch to origin
cd .worktrees/issue-164 && git push -u origin issue-164

# 3. Create DevPod workspace
devpod up . --branch issue-164 --id issue-164
```

#### Option C: Direct from GitHub (no local worktree)

```bash
devpod up github.com/YOUR_ORG/frontman \
  --branch feature/new-feature \
  --id new-feature
```

Each workspace is isolated with its own:
- Git checkout
- Node modules
- Elixir deps
- Build artifacts

### Local Worktrees (Without DevPod)

For local-only development without the remote server:

```bash
# Create local worktree
make worktree-create BRANCH=my-feature

# Work in the worktree
cd .worktrees/my-feature
make install
make dev
```

Each worktree has an isolated `.claude/` directory for Claude Code context.

See `AGENTS.md` for more on the worktree workflow.

### Managing Workspaces

```bash
# List all workspaces
devpod list

# Stop a workspace (preserves state)
devpod stop my-feature

# Start a stopped workspace
devpod up my-feature

# Delete a workspace (removes container and data)
devpod delete my-feature
```

## Database

PostgreSQL runs on the host server and is shared across all workspaces.

- **Host:** `host.docker.internal` (from inside containers)
- **Port:** 5432
- **Database:** `frontman_server_dev`
- **User:** `postgres`
- **Password:** `postgres`

The `DATABASE_URL` environment variable is automatically set in the devcontainer.

### Creating Additional Databases

If you need isolated databases per workspace:

```bash
# SSH into the server
ssh root@77.42.16.199

# Create a new database
sudo -u postgres createdb frontman_feature_xyz

# Then set DATABASE_URL in your workspace
export DATABASE_URL="postgres://postgres:postgres@host.docker.internal:5432/frontman_feature_xyz"
```

## Troubleshooting

### Connection Issues

```bash
# Test SSH connection
ssh root@77.42.16.199 'echo "Connected!"'

# Check Docker is running on server
ssh root@77.42.16.199 'docker ps'

# Check DevPod provider configuration
devpod provider list
```

### Workspace Won't Start

```bash
# View workspace logs
devpod logs my-feature

# Rebuild the workspace
devpod up my-feature --recreate
```

### Port Forwarding Not Working

DevPod handles port forwarding automatically. If ports aren't accessible:

```bash
# Check which ports are forwarded
devpod status my-feature

# Manually forward a port
devpod ssh my-feature -- -L 4000:localhost:4000
```

### Out of Disk Space

```bash
# SSH into server and clean Docker
ssh root@77.42.16.199 'docker system prune -a'

# Check disk usage
ssh root@77.42.16.199 'df -h'
```

## Server Maintenance

### Checking Server Status

```bash
ssh root@77.42.16.199 << 'EOF'
echo "=== Docker ==="
docker ps

echo ""
echo "=== PostgreSQL ==="
systemctl status postgresql | head -5

echo ""
echo "=== Disk Usage ==="
df -h /

echo ""
echo "=== Memory ==="
free -h
EOF
```

### Updating the Server

```bash
ssh root@77.42.16.199 << 'EOF'
apt update && apt upgrade -y
docker system prune -f
EOF
```

## Resource Limits

The CX43 server has:
- 8 shared vCPUs
- 16GB RAM
- 160GB NVMe SSD

Estimated usage per workspace:
- ~1.5-2GB RAM (with all dev servers running)
- ~5-10GB disk (deps, node_modules, build artifacts)

**Recommended:** Run 3-5 concurrent workspaces comfortably.

## Security Notes

1. **SSH Key Auth:** Password authentication should be disabled after initial setup
2. **Firewall:** Only SSH (port 22) is exposed; all other ports are tunneled
3. **Database:** PostgreSQL only accepts connections from Docker network and localhost
