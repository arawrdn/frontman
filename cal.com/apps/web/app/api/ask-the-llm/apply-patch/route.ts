import * as fs from "node:fs";
import path from "node:path";
import { NextResponse } from "next/server";
import { z } from "zod";
import { defaultResponderForAppDir } from "../../defaultResponderForAppDir";

const ApplyPatchSchema = z.object({
	filePath: z.string(),
	patch: z.string(),
	description: z.string(),
});

async function handleApplyPatch(req: Request): Promise<NextResponse> {
	try {
		const body = await req.json();
		const { filePath, patch, description } = ApplyPatchSchema.parse(body);

		// Security check
		const projectRoot = process.cwd();
		const resolvedPath = path.resolve(projectRoot, filePath);

		if (!resolvedPath.startsWith(projectRoot)) {
			return NextResponse.json(
				{ success: false, error: "Access denied" },
				{ status: 403 },
			);
		}

		// Write file
		await fs.promises.writeFile(resolvedPath, patch, "utf-8");

		return NextResponse.json({
			success: true,
			message: `Successfully applied changes to ${filePath}. ${description}`,
		});
	} catch (error) {
		console.error("Apply patch error:", error);
		return NextResponse.json(
			{
				success: false,
				error: error instanceof Error ? error.message : "Unknown error",
			},
			{ status: 500 },
		);
	}
}

export const POST = defaultResponderForAppDir(handleApplyPatch);
