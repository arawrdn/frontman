declare module "@ask-the-llm/nextjs/src/Nextjs__Middleware.res.mjs" {
    export function createMiddleware(config: any): (req: any) => Promise<any>;
}

declare module "@ask-the-llm/nextjs/src/Vite__Middleware.res.mjs" {
    export function createMiddleware(config: any): (req: any) => Promise<option<any>>;
}

declare module "@ask-the-llm/nextjs/src/Nextjs__Config.res.mjs" {
    export function make(
        isDev?: boolean, 
        basePath?: string, 
        clientUrl?: string, 
        clientCssUrl?: string, 
        entrypointUrl?: string,
        isLightTheme?: boolean
    ): any;
}

