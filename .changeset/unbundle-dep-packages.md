---
"@frontman-ai/frontman-protocol": patch
"@frontman/bindings": patch
"@frontman-ai/frontman-core": patch
---

First npm publish of @frontman-ai/frontman-protocol, @frontman/bindings, and
@frontman-ai/frontman-core as standalone packages. Previously these were bundled
inside the framework wrappers (astro, vite, nextjs). They are now declared as
explicit dependencies and installed by the client's package manager.
