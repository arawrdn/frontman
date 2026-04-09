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
