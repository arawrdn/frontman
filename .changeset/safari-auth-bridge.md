---
"@frontman-ai/client": patch
"@frontman-ai/frontman-client": patch
---

Fix Safari auth redirects by adding a storage-access auth bridge. When third-party cookie access is blocked, the Frontman client now opens a secure `auth-bridge` iframe, requests storage access from inside that iframe when needed, and retries the ACP connection with the returned socket token instead of immediately redirecting the whole page.
