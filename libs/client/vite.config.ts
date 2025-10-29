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
});
