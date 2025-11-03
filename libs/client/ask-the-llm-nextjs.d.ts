declare module "@ask-the-llm/nextjs/src/Nextjs__ApiRoute.res.mjs" {
	export function createUIHandler({isDev, entrypointUrl}: {isDev: boolean, entrypointUrl?: string}): (req: any, res: any) => Promise<void>;
	export function createChatHandler(): (req: any, res: any) => Promise<void>;
	export function createStreamHandler(): (req: any, res: any) => Promise<void>;
}

