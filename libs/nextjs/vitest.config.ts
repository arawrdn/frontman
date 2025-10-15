import { defineConfig } from "vitest/config";
import dotenv from "dotenv";

// Load environment variables from .env
dotenv.config();

export default defineConfig({
	test: {
		// Run tests in Node.js environment
		environment: "node",

		// Increase timeout for LLM calls and subprocess tests
		testTimeout: 60000,

		// Pattern for test files
		include: ["test/**/*.test.res.mjs"],

		// Allow console output from tests
		silent: false,

		// Coverage configuration (optional)
		coverage: {
			provider: "v8",
			reporter: ["text", "json", "html"],
			include: ["src/**/*.res.mjs"],
			exclude: ["src/**/*.res.d.ts", "test/**"],
		},
	},
});
