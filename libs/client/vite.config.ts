import path from "node:path";
import type { IncomingMessage, ServerResponse } from "node:http";
import createReScriptPlugin from "@jihchi/vite-plugin-rescript";
import tailwindcss from "@tailwindcss/vite";
import * as vite from "vite";

import {
	createUIHandler,
	createChatHandler,
	createStreamHandler,
} from "@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs";

// Helper to adapt Next.js handlers to Vite middleware
const adaptNextJsHandler = (handler: any) => {
	return async (req: IncomingMessage, res: ServerResponse) => {
		// @ts-ignore
		res.status = (status: number) => {
			res.statusCode = status;
			return res;
		};
	// Parse request body
	const body = await new Promise((resolve) => {
		let bodyStr = "";
		req.on("data", (chunk: Buffer) => {
			bodyStr += chunk.toString();
		});
		req.on("end", () => {
			try {
				resolve(bodyStr ? JSON.parse(bodyStr) : {});
			} catch {
				resolve({});
			}
		});
	});

	// Adapt the request to match Next.js API format by adding properties
	// We don't spread to preserve the IncomingMessage prototype methods
	// @ts-ignore
	req.query = Object.fromEntries(
		new URL(req.url || "", `http://${req.headers.host}`).searchParams,
	);
	// @ts-ignore
	req.body = body;

	await handler(req, res);
	};
};

// Create Vite plugin for API routes
const apiRoutesPlugin = (): vite.Plugin => {
	const isDev = process.env.NODE_ENV !== "production";
	let uiHandler: any;
	let chatHandler: any;
	let streamHandler: any;

	return {
		name: "ask-the-llm-api-routes",
		configureServer(server) {
			uiHandler = createUIHandler({isDev, isLightTheme: true, entrypointUrl: "http://localhost:3000/api/ask-the-llm"});
			chatHandler = createChatHandler();
			streamHandler = createStreamHandler();

			server.middlewares.use(
				async (
					req: IncomingMessage,
					res: ServerResponse,
					next: () => void,
				) => {
					const url = req.url || "";

					try {
						// Handle /api/ask-the-llm (exact match) - UI handler
						if (
							url === "/api/ask-the-llm" ||
							url.startsWith("/api/ask-the-llm?")
						) {
							await adaptNextJsHandler(uiHandler)(req, res);
							return;
						}

						// Handle /api/ask-the-llm/chat - Chat handler
						if (
							url === "/api/ask-the-llm/chat" ||
							url.startsWith("/api/ask-the-llm/chat?")
						) {
							await adaptNextJsHandler(chatHandler)(req, res);
							return;
						}

						// Handle /api/ask-the-llm/chat-sse - SSE stream handler
						if (
							url === "/api/ask-the-llm/chat-sse" ||
							url.startsWith("/api/ask-the-llm/chat-sse?")
						) {
							await adaptNextJsHandler(streamHandler)(req, res);
							return;
						}

						// Not an API route, continue to next middleware
						next();
					} catch (error) {
						console.error("API route error:", error);
						res.statusCode = 500;
						res.end("Internal Server Error");
					}
				},
			);
		},
	};
};

export default vite.defineConfig({
	plugins: [createReScriptPlugin(), tailwindcss(), apiRoutesPlugin()],
	resolve: {
		alias: {
			"@": path.resolve(__dirname, "./src"),
		},
	},
	build: {
		lib: {
			entry: path.resolve(__dirname, "./src/Main.res.mjs"),
			formats: ["es"],
			fileName: "index",
		},
		rollupOptions: {
			external: [
				"react",
				"react-dom",
				"react/jsx-runtime",
				/^node:.*/,
			],
			output: {
				preserveModules: true,
				preserveModulesRoot: "src",
			},
		},
	},
});
