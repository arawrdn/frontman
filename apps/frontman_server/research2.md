---
date: 2026-01-19T00:00:00Z
researcher: Claude
git_commit: 9e8fe49eade53053d070df428b4c43fc8563afaa
branch: auth_pages
repository: frontman
topic: "Authentication Flow Between frontman-core, frontman_server, and frontman-client"
tags: [research, authentication, websocket, session, scope]
status: complete
last_updated: 2026-01-19
---

# Research: Authentication Flow Between frontman-core, frontman_server, and frontman-client

**Date**: 2026-01-19
**Git Commit**: `9e8fe49eade53053d070df428b4c43fc8563afaa`
**Branch**: `auth_pages`
**Repository**: frontman

---

## Research Question

How does authentication currently work between `libs/frontman-core/`, `apps/frontman_server/`, and `libs/frontman-client/`?

---

## Summary

Authentication in Frontman is implemented **entirely in the server** (`frontman_server`). The `frontman-core` library contains no authentication code, and `frontman-client` only has protocol-level type definitions for auth methods that the server can advertise.

The system uses a **hybrid model**:
- **HTTP routes**: Session-based auth with cookies, magic link login (primary), and email/password (secondary)
- **WebSocket (ACP protocol)**: Currently uses a **hardcoded dev user lookup** (`dev@frontman.local`) - not integrated with HTTP session auth

---

## Component Breakdown

### 1. `libs/frontman-core/` — No Auth Code

This library contains ReScript tools (Grep, ReadFile, WriteFile, etc.) and SSE handling. **No authentication-related files exist here.**

---

### 2. `apps/frontman_server/` — Full Auth Implementation

#### Authentication Methods

| Method | Primary Flow |
|--------|-------------|
| **Magic Link** | Email → Token emailed → Click link → Session created |
| **Password** | Email + Password → Bcrypt verify → Session created |

#### Key Files

| File | Purpose |
|------|---------|
| `lib/frontman_server_web/user_auth.ex` | Session management plugs (`log_in_user`, `log_out_user`, `fetch_current_scope_for_user`) |
| `lib/frontman_server/accounts.ex` | Domain logic for user auth (`login_user_by_magic_link/1`, `get_user_by_email_and_password/2`) |
| `lib/frontman_server/accounts/user.ex` | User schema with Bcrypt password validation |
| `lib/frontman_server/accounts/user_token.ex` | Token generation/verification (session tokens, magic link tokens) |
| `lib/frontman_server/accounts/scope.ex` | Scope struct wrapping user + organization context |
| `lib/frontman_server_web/router.ex` | Auth routes and pipeline definitions |
| `lib/frontman_server_web/channels/user_socket.ex` | WebSocket auth (currently hardcoded) |

#### Session Token Flow

1. After login, `UserToken.build_session_token/1` generates 32 random bytes
2. Token stored in database with context `"session"` and `authenticated_at` timestamp
3. Token placed in Plug session via `put_session(:user_token, token)`
4. Optionally written to remember-me cookie (14-day validity)
5. On subsequent requests, `fetch_current_scope_for_user` plug validates token and builds `Scope`

#### Magic Link Token Flow

1. User requests magic link at `POST /users/log-in`
2. `UserToken.build_email_token/2` generates token, stores SHA-256 hash in DB
3. Unhashed token sent via email (15-minute validity)
4. User clicks link → `GET /users/log-in/:token`
5. Token verified, user shown confirmation page
6. On submit → session created, token deleted

#### Auth Plugs in Router (`router.ex:13`)

```elixir
pipeline :browser do
  # ...
  plug :fetch_current_scope_for_user  # Always runs
end
```

| Plug | Purpose |
|------|---------|
| `fetch_current_scope_for_user` | Populates `conn.assigns.current_scope` from session token |
| `require_authenticated_user` | Redirects to login if no valid scope |
| `redirect_if_user_is_authenticated` | Redirects logged-in users away from auth pages |
| `fetch_organization` | Adds organization to scope for `/orgs/:org_slug/*` routes |

#### WebSocket Auth — Current State (`user_socket.ex:12-21`)

```elixir
def connect(_params, socket, _connect_info) do
  case Accounts.get_user_by_email("dev@frontman.local") do
    nil -> {:error, :no_dev_user}
    user -> {:ok, assign(socket, :scope, Scope.for_user(user))}
  end
end
```

**Current behavior**: Ignores connection params and session data. Hardcoded lookup of `dev@frontman.local` user.

---

### 3. `libs/frontman-client/` — ACP Protocol Types Only

The client library has no user authentication logic. It defines types for auth methods that the server *could* advertise during protocol initialization.

#### `authMethod` Type (`FrontmanClient__ACP__Types.res:62-68`)

```rescript
type authMethod = {
  id: string,
  name: string,
  description: option<string>,
}
```

#### Where It's Used (`FrontmanClient__ACP__Types.res:90-91`)

```rescript
type initializeResult = {
  // ...
  authMethods: option<array<authMethod>>,
}
```

The `authMethods` field is part of the ACP `initialize` response. The server can optionally advertise available auth methods, but **the client currently does nothing with this field**.

#### Client Connection Flow (`FrontmanClient__ACP.res:83-131`)

1. Client creates Phoenix socket pointing to `ws://localhost:4000/socket`
2. Socket connects → `UserSocket.connect/3` fires (hardcoded user lookup)
3. Client joins `"tasks"` channel
4. Client sends `initialize` request
5. Server responds with `initializeResult` (may include `authMethods`)
6. Connection state set to `Initialized(result)`

---

## Connection Points Between Components

| Server | Client | Connection |
|--------|--------|------------|
| `endpoint.ex:20-23` (`/socket`) | `Main.res:4` (`ws://localhost:4000/socket`) | WebSocket endpoint |
| `user_socket.ex:8` (`"tasks"`) | `Constants.tasksTopic` | Channel topic |
| `user_socket.ex:9` (`"task:*"`) | `Constants.makeTaskTopic(sessionId)` | Session channel pattern |
| `tasks_channel.ex:25` (`"acp:message"`) | `Constants.acpMessageEvent` | ACP message event |

---

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        HTTP/Browser Auth                             │
├─────────────────────────────────────────────────────────────────────┤
│  Browser Request                                                     │
│       │                                                              │
│       ▼                                                              │
│  router.ex (:browser pipeline)                                       │
│       │                                                              │
│       ▼                                                              │
│  fetch_current_scope_for_user (user_auth.ex:71)                     │
│       │                                                              │
│       ▼                                                              │
│  Session Token → Accounts.get_user_by_session_token → Scope         │
│       │                                                              │
│       ▼                                                              │
│  conn.assigns.current_scope                                          │
└─────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────┐
│                      WebSocket/ACP Auth                              │
├─────────────────────────────────────────────────────────────────────┤
│  ReScript Client (frontman-client)                                   │
│       │                                                              │
│       ▼                                                              │
│  ACP.connect → Phoenix Socket (/socket)                              │
│       │                                                              │
│       ▼                                                              │
│  UserSocket.connect (user_socket.ex:12)                             │
│       │                                                              │
│       ▼                                                              │
│  HARDCODED: get_user_by_email("dev@frontman.local")                 │
│       │                                                              │
│       ▼                                                              │
│  socket.assigns.scope                                                │
│       │                                                              │
│       ▼                                                              │
│  TasksChannel / TaskChannel access scope                             │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Code References

### HTTP Auth

- `apps/frontman_server/lib/frontman_server_web/user_auth.ex:39-45` — `log_in_user/3`
- `apps/frontman_server/lib/frontman_server_web/user_auth.ex:71-80` — `fetch_current_scope_for_user/2`
- `apps/frontman_server/lib/frontman_server/accounts.ex:221-247` — `login_user_by_magic_link/1`
- `apps/frontman_server/lib/frontman_server/accounts/user_token.ex:87-101` — `build_email_token/2`
- `apps/frontman_server/lib/frontman_server/accounts/scope.ex:24-27` — Scope struct

### WebSocket Auth

- `apps/frontman_server/lib/frontman_server_web/channels/user_socket.ex:12-21` — `connect/3`
- `apps/frontman_server/lib/frontman_server_web/channels/tasks_channel.ex:70` — scope usage
- `apps/frontman_server/lib/frontman_server_web/channels/task_channel.ex:22` — task ownership check

### Client ACP Types

- `libs/frontman-client/src/FrontmanClient__ACP__Types.res:62-68` — `authMethod` type
- `libs/frontman-client/src/FrontmanClient__ACP__Types.res:82-92` — `initializeResult` with `authMethods`
- `libs/frontman-client/src/FrontmanClient__ACP.res:83-131` — `connect` function

---

## Key Findings

1. **No auth in frontman-core** — It's a pure tools library

2. **HTTP auth is complete** — Full implementation with magic link, password, session tokens, remember-me, and sudo mode

3. **WebSocket auth is a stub** — Currently hardcoded to `dev@frontman.local`, does not integrate with HTTP session

4. **Scope pattern throughout** — The `Scope` struct (user + optional org) flows through both HTTP and WebSocket layers to enforce multi-tenancy

5. **Client has auth type definitions but no logic** — The `authMethod` type exists in the ACP protocol types, but the client doesn't implement any auth UI or token handling

---

## Open Questions

1. How should WebSocket auth integrate with HTTP session auth?
2. Should the client pass session tokens when connecting to the socket?
3. What happens to existing WebSocket connections when a user logs out?
