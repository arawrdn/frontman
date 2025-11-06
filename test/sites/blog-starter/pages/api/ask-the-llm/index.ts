import { createUIHandler } from "@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs";

// Create the handler with isDev parameter
// Use true for development, false for production
const isDev = process.env.NODE_ENV !== "production";

export default createUIHandler({isDev, clientCssUrl: "http://localhost:5173/src/index.css"});
