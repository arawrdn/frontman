import path from "node:path";
import createReScriptPlugin from "@jihchi/vite-plugin-rescript";
import tailwindcss from "@tailwindcss/vite";
import * as vite from "vite";

export default vite.defineConfig({
	plugins: [createReScriptPlugin(), tailwindcss()],
	resolve: {
		alias: {
			"@": path.resolve(__dirname, "./src"),
		},
	},
	server: {
		proxy: {
			"/nextjs": {
				target: "http://localhost:3000",
				changeOrigin: true,
				rewrite: (path) => path.replace(/^\/nextjs/, ""),
			},
			"/_next": {
				target: "http://localhost:3000",
				changeOrigin: true,
			},
			"/api": {
				target: "http://localhost:3000",
				changeOrigin: true,
			},
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
