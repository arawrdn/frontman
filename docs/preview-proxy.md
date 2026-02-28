# Preview Proxy

> Live preview sharing for stakeholders via HTTP-over-WebSocket tunneling

Frontman's preview iframe currently points at `localhost` — stakeholders must be on the developer's machine to see the app. The preview proxy tunnels the local dev server through the Frontman API server so anyone with a link can see the app and use the full Frontman UI (chat + preview).

## Architecture

### Why subdomain routing

Path-based routing (`preview.frontman.sh/p/<id>/some/page`) breaks root-relative paths. When the app emits `/styles.css`, the browser requests `preview.frontman.sh/styles.css` — missing the `/p/<id>/` prefix, so the proxy can't route it. You end up rewriting URLs in HTML, CSS `url()`, JS dynamic imports, source maps, framework chunking conventions. It's an open-ended problem.

Subdomain routing (`<slug>.preview.frontman.sh/some/page`) makes the proxy transparent. Every path the app emits resolves relative to the subdomain origin. The proxy forwards the path suffix to localhost verbatim. No parsing, no rewriting.

### Tunnel protocol

HTTP-over-WebSocket via Phoenix Channels. The developer's browser is the tunnel relay.

```
Stakeholder                 Frontman Server              Developer's Browser
(browser)                   (api.frontman.sh)            (localhost)
    |                            |                            |
    |  GET /some/page            |                            |
    |--------------------------->|                            |
    |                            |  preview:request           |
    |                            |  {req_id, method, path,    |
    |                            |   headers, body}           |
    |                            |--------------------------->|
    |                            |                            |
    |                            |              fetch("http://localhost:3000/some/page")
    |                            |                            |
    |                            |  preview:response          |
    |                            |  {req_id, status,          |
    |                            |   headers, body}           |
    |                            |<---------------------------|
    |  200 OK                    |                            |
    |<---------------------------|                            |
```

### Why the browser is the relay

No new daemon or CLI binary needed. The browser client already has:
- An authenticated WebSocket to the Phoenix server (via `UserSocket`)
- Direct `fetch()` access to the local dev server (same machine, no CORS)
- The connection lifecycle is already managed by `Client__ConnectionReducer`

The tunnel is a new Phoenix channel (`preview_tunnel:<slug>`) on the existing socket. The client joins it alongside the existing `task:*` channel.

### Why not alternatives

**External tunnels (ngrok, Cloudflare Tunnel):** Adds an external dependency and cost. Data leaves our infrastructure. Each developer needs a tunnel binary installed. Frontman should be self-contained.

**Dedicated WebSocket protocol:** More efficient for streaming, but introduces a second WebSocket endpoint with separate auth, deployment surface, and connection management. Phoenix channels already handle multiplexing, heartbeats, and reconnection.

## Request/response frame protocol

### Request frame (server → client)

```json
{
  "req_id": "uuid",
  "method": "GET",
  "path": "/some/page",
  "headers": [["accept", "text/html"], ["cookie", "sid=abc"]],
  "body": null
}
```

### Response frame (client → server)

Small responses (< 256KB) go as a single frame:

```json
{
  "req_id": "uuid",
  "status": 200,
  "headers": [["content-type", "text/html"], ["set-cookie", "sid=xyz"]],
  "body_base64": "PGh0bWw+Li4u"
}
```

Large responses use chunked frames:

```json
{ "req_id": "uuid", "status": 200, "headers": [...], "chunk": "base64...", "done": false }
{ "req_id": "uuid", "chunk": "base64...", "done": false }
{ "req_id": "uuid", "chunk": "base64...", "done": true }
```

Phase 2 replaces Base64 with binary WebSocket frames for ~2x bandwidth improvement.

## Start/stop flow

### Starting a preview

1. Developer clicks "Share Preview" in the WebPreview navigation bar.
2. Client dispatches `StartPreviewProxy` through the state reducer.
3. Effect sends a request on the tasks channel (or a REST endpoint) to create a tunnel.
4. Server creates a `preview_tunnels` row:

   | Column | Value |
   |--------|-------|
   | `id` | UUID |
   | `slug` | 8-char nanoid (URL-safe, e.g. `k3xp9m2q`) |
   | `user_id` | developer's user ID |
   | `status` | `active` |
   | `access_mode` | `open` (default) |
   | `expires_at` | now + 24h |

5. Server responds with the preview URL: `https://k3xp9m2q.preview.frontman.sh`
6. Client joins `preview_tunnel:k3xp9m2q` channel.
7. Client shows the URL in a copy-to-clipboard popover.

### Stopping a preview

- Developer clicks the toggle button again (or closes the share popover).
- Client sends `preview:stop` and leaves the tunnel channel.
- Server marks the tunnel as `stopped`.
- Subsequent stakeholder requests get a static "Preview session ended" page.

### Dev server restart

The tunnel channel stays open (it's browser ↔ server, not browser ↔ dev server). When the dev server restarts, the relay's `fetch()` to localhost fails temporarily. The proxy returns a 502 "Developer's server is restarting" page. Once the dev server is back, the next request works.

### Browser tab close

- WebSocket disconnects, `terminate/2` fires on the tunnel channel.
- Server marks the tunnel as `paused`.
- If the developer reopens Frontman within 5 minutes, the tunnel resumes with the same slug.
- After 5 minutes, the tunnel is marked `stopped`.

### Automatic expiration

Tunnels expire after 24 hours. A periodic `Task` (or `Oban` job) cleans up expired records.

## Branch switching

The preview URL is tied to the developer's session, not a git branch. When the developer switches branches:

- The dev server restarts (HMR or full restart).
- The tunnel stays open.
- The stakeholder refreshes and sees the new branch.

The developer's client can optionally detect branch changes and send metadata:

```json
{"event": "preview:metadata", "branch": "feature/dark-mode", "commit": "a1b2c3d"}
```

The server surfaces this to the stakeholder as an info badge: "Viewing: feature/dark-mode (a1b2c3d)".

If branch-specific URLs are needed later, it can be an opt-in feature ("pin this preview to branch X").

## Stakeholder experience

### What they see

The full Frontman UI: chat panel + preview iframe, side by side. The preview iframe loads the app through the tunnel. The stakeholder can:

- Browse the app (navigate, click, scroll)
- Chat with the AI assistant (send text prompts)
- See the developer's conversation history (read-only)

Tool calls (file editing, terminal commands) are **blocked server-side** for stakeholders. The task channel checks the user's role before routing tool calls to MCP.

### Developer offline

The stakeholder sees a branded "Preview Paused" page:

```
Preview Paused
The developer's machine is currently offline.
This page will automatically reconnect when they're back.
[spinner]
```

The page auto-retries with exponential backoff. When the developer reconnects, the tunnel resumes and the page auto-recovers.

### URL structure

```
https://k3xp9m2q.preview.frontman.sh          → Frontman UI (HTML shell)
https://k3xp9m2q.preview.frontman.sh/         → tunneled to localhost:3000/
https://k3xp9m2q.preview.frontman.sh/api/data → tunneled to localhost:3000/api/data
```

The Frontman UI is served by the server for the root path (like the existing suffix-based routing). All other paths are proxied through the tunnel.

## Auth

### Access modes

| Mode | How it works | Use case |
|------|-------------|----------|
| **Open** (default) | Anyone with the link can view | Quick sharing, demos |
| **Token-protected** | JWT in query string, server sets session cookie after validation | Controlled sharing, expiring access |
| **Password-protected** | Developer sets a password, stakeholder enters it once | Client-facing previews |

### Token structure

```json
{
  "sub": "preview:k3xp9m2q",
  "exp": 1735689600,
  "role": "viewer",
  "iss": "frontman"
}
```

The developer generates share links from the UI. Each link embeds a JWT:

```
https://k3xp9m2q.preview.frontman.sh?token=eyJhbG...
```

On first visit, the server validates the JWT and sets a session cookie. Subsequent requests use the cookie — the token doesn't need to be in every URL.

### Revocation

- **Stop sharing:** Immediate — tunnel closes, all access ends.
- **Regenerate slug:** Old links stop working. New slug, new URL.
- **Token expiration:** Built-in (default 24h, configurable per link).
- **Active sessions list:** Developer can see connected viewers in the share popover and revoke individually.

## Pitfalls and mitigations

### WebSocket upgrades (HMR)

Dev servers open WebSocket connections for hot reload (`/__vite_hmr`, `/_next/webpack-hmr`, etc.). In **Phase 1**, these are dropped with a "HMR not available in preview mode" message — the app still works, it just won't hot-reload for the stakeholder. In **Phase 2**, WebSocket passthrough is added by having the tunnel bridge WebSocket frames.

### `Location` headers

A `302 Location: http://localhost:3000/login` breaks everything. The server rewrites `Location` headers, replacing `http(s)://localhost:<port>` with `https://<slug>.preview.frontman.sh`.

### Cookies

If the dev server sets `Set-Cookie: sid=abc; Domain=localhost`, the browser won't send it back through the preview domain. The server strips the `Domain` attribute from `Set-Cookie` headers. The browser scopes the cookie to the preview subdomain, which is correct.

### Streaming / SSE

Server-Sent Events and chunked transfer encoding need the proxy to flush incrementally. The Phoenix plug uses `Plug.Conn.send_chunked/2` and `Plug.Conn.chunk/2` to stream response chunks as they arrive from the tunnel — no buffering the full response.

### Mixed content

The preview is served over HTTPS but the local dev server speaks HTTP. The tunnel handles this transparently — the browser talks HTTPS to the proxy, the relay talks HTTP to localhost. No mixed-content issues because the browser never sees the HTTP origin.

### Concurrent requests

Multiple stakeholders (or one stakeholder with many parallel asset requests) send requests through the tunnel simultaneously. Each request has a unique `req_id`. The tunnel channel maintains a `req_id → waiting_process_pid` map. The plug sends a request via `send/2` and blocks in a `receive` loop. When the response arrives, the channel forwards it to the waiting process.

### Response size limit

10MB per response. Larger responses (videos, large images) get a 413. This is a pragmatic limit for the tunnel — most dev server responses are well under this.

### Request timeout

30 seconds per request. If the dev server doesn't respond within this window, the proxy returns a 504 Gateway Timeout.

## Infrastructure requirements

### DNS

Add a wildcard A record pointing to the production server:

```
*.preview.frontman.sh  A  <server-ip>
```

### Caddy

Add wildcard subdomain to the Caddyfile (requires Caddy DNS plugin for ACME DNS challenge since wildcard certs can't use HTTP challenge):

```
*.preview.frontman.sh {
    tls {
        dns cloudflare {env.CLOUDFLARE_API_TOKEN}
    }
    reverse_proxy localhost:{PORT}
}
```

### WebSocket origin check

Already covered. `config/runtime.exs` allows `//*.frontman.sh` by default:

```elixir
check_origin: ["//frontman.sh", "//*.frontman.sh", "//localhost"]
```

### Database

New `preview_tunnels` table:

```sql
CREATE TABLE preview_tunnels (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug VARCHAR(16) NOT NULL,
  user_id UUID NOT NULL REFERENCES users(id),
  status VARCHAR(20) NOT NULL DEFAULT 'active',
  access_mode VARCHAR(20) NOT NULL DEFAULT 'open',
  password_hash VARCHAR(255),
  expires_at TIMESTAMPTZ NOT NULL,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT preview_tunnels_slug_unique UNIQUE (slug)
);

CREATE INDEX preview_tunnels_user_id_index ON preview_tunnels(user_id);
CREATE INDEX preview_tunnels_status_index ON preview_tunnels(status) WHERE status = 'active';
```

### Phoenix channel

Add to `UserSocket`:

```elixir
channel("preview_tunnel:*", FrontmanServerWeb.PreviewTunnelChannel)
```

### Endpoint plug

Insert `PreviewProxy` plug early in the Endpoint pipeline — before `Plug.Parsers` and the `Router`, since preview requests should bypass normal request parsing:

```elixir
# In endpoint.ex, before Plug.Parsers:
plug(FrontmanServerWeb.Plugs.PreviewProxy)
```

## Implementation phases

### Phase 1: MVP

Basic tunnel. No auth, no HMR passthrough, no streaming optimization.

**Server:**
- `preview_tunnels` context, schema, migration
- `TunnelRegistry` (ETS-backed, registered in supervision tree)
- `PreviewTunnelChannel` (join, request/response handling)
- `PreviewProxy` plug (subdomain detection, request serialization, response relay)
- Caddyfile update, DNS wildcard record

**Client:**
- `Client__PreviewProxy` module (relay logic: receive request frame, fetch localhost, send response frame)
- State reducer actions: `StartPreviewProxy`, `StopPreviewProxy`, success/error variants
- Share button in `Client__WebPreview` navigation bar
- Tunnel channel lifecycle in `Client__ConnectionReducer`

### Phase 2: Polish

- Chunked/streaming response support (SSE, large assets)
- WebSocket passthrough for HMR
- Binary frames instead of Base64
- `Location` header rewriting
- `Set-Cookie` domain stripping
- "Dev server offline" / "Restarting" intermediate pages
- Branch metadata display for stakeholders

### Phase 3: Auth and chat

- Token-protected and password-protected access modes
- Share dialog with access mode selector, link generation, active viewers list
- Stakeholder viewer mode in the Frontman client (chat enabled, tools blocked)
- Server-side role enforcement for tool calls

## Key files

| File | Relevance |
|------|-----------|
| `apps/frontman_server/lib/frontman_server_web/endpoint.ex` | Where `PreviewProxy` plug is inserted |
| `apps/frontman_server/lib/frontman_server_web/channels/user_socket.ex` | Add `preview_tunnel:*` channel |
| `apps/frontman_server/config/runtime.exs` | `check_origin` already covers `*.frontman.sh` |
| `infra/production/Caddyfile.template` | Add wildcard subdomain block |
| `libs/client/src/webpreview/Client__WebPreview.res` | Navigation bar — add share button |
| `libs/client/src/Client__ConnectionReducer.res` | Channel lifecycle state machine |
| `libs/frontman-core/src/FrontmanCore__Hosts.res` | Add `previewHost` constant |
| `libs/frontman-core/src/FrontmanCore__UIShell.res` | HTML shell generation (reuse for stakeholder view) |
| `libs/frontman-client/src/FrontmanClient__Relay.res` | Pattern reference for localhost fetch |
