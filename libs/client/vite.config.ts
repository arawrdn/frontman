import path from "node:path";
import tailwindcss from "@tailwindcss/vite";
import biome from "vite-plugin-biome";
import * as vite from "vite";

export default vite.defineConfig({
	plugins: [tailwindcss(), biome({mode: "lint", "files": "."})],
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
				/^node:.*/,
			],
			output: {
				inlineDynamicImports: true,
			},
		},
	},
});
