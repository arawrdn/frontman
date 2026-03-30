---
"frontman": patch
---

Fix task title generation so the background worker receives the same model selection and forwarded env API keys as the original prompt, preventing titles from getting stuck on `New Task` when chat execution succeeds.
