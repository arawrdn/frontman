import { defineConfig } from "vite";
import { resolve } from "path";
import dts from "vite-plugin-dts";

export default defineConfig({
	build: {
		ssr: true,
		lib: {
			entry: resolve(__dirname, "index.ts"),
			formats: ["es"],
			fileName: () => "index.js",
		},
		rollupOptions: {
			external: [
				"vite",
				"fs",
				"node:path",
				"next",
				"node:fs",
				"path",
				"node:http",
				"node:https",
				"node:crypto",
				"node:os",
				"node:stream",
				"node:url",
				"node:buffer",
				"node:util",
				"node:events",
				"node:child_process",
				"node:module",
			],
			output: {
				preserveModules: false,
				inlineDynamicImports: true,
			},
		},
		outDir: "dist",
		sourcemap: true,
		minify: false,
		target: "node18",
	},
	plugins: [
		dts({
			rollupTypes: true,
		}),
	],
	ssr: {
		noExternal: true,
	},
});

