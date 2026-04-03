---
"@frontman-ai/client": patch
---

fix: show cookie guidance when embedded sign-in may be blocked

Embedded Frontman now shows a browser-specific notice when Safari or a likely
third-party-cookie block prevents sign-in from completing. The modal explains
how to enable the needed cookie setting and lets the user retry sign-in after
updating their browser configuration.
