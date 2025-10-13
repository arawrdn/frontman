import { defineConfig } from "vitest/config";

export default defineConfig({
	test: {
		// Run tests in Node.js environment
		environment: "node",

		// Increase timeout for subprocess tests (default is 5s)
		testTimeout: 10000,

		// Pattern for test files
		include: ["test/*.test.res.mjs"],

		// Allow console output from tests
		silent: false,

		// Coverage configuration (optional, for future use)
		coverage: {
			provider: "v8",
			reporter: ["text", "json", "html"],
			include: ["src/**/*.res.mjs"],
			exclude: ["src/**/*.res.d.ts", "test/**"],
		},
	},
});
