import { NextResponse } from "next/server";
import type { NextRequest } from "next/server";
import { createMiddleware, makeConfig } from "@ask-the-llm/frontman-nextjs/src/FrontmanNextjs.res.mjs";

export const config = {
	runtime: "nodejs",
};

const frontmanMiddleware = createMiddleware(makeConfig({
	projectRoot: process.cwd(),
	serverName: "blog-starter",
	serverVersion: "1.0.0",
}))

export default async function middleware(request: NextRequest) {
	const response = await frontmanMiddleware(request);
	if (response) {
		return response;
	}
	return NextResponse.next();
}
