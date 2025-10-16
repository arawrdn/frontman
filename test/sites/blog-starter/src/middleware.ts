import { createMiddleware, config } from '@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs';

let middleware = createMiddleware(true)

export { middleware, config }