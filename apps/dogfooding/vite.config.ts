import * as vite from "vite";
import { askTheLlmPlugin } from "@ask-the-llm/vite-plugin";

// Plugin to ensure client library imports are handled correctly
const fixReactImports = (): vite.Plugin => {
	return {
		name: "fix-react-imports",
		enforce: "pre",
		transform(code, id) {
			// Only transform the client library files
			if (id.includes("@ask-the-llm/client") || id.includes("node_modules/@ask-the-llm/client")) {
				// React 19 should export jsxs and Fragment from jsx-runtime, but if there are issues,
				// we can log them for debugging
				return code;
			}
			return null;
		},
	};
};

export default vite.defineConfig({
	server: {
		port: 6123,
	},
	optimizeDeps: {
		include: ["react", "react-dom", "react/jsx-runtime"],
		exclude: ["@ask-the-llm/client"],
	},
	resolve: {
		dedupe: ["react", "react-dom"],
	},
	plugins: [
		fixReactImports(),
		askTheLlmPlugin({
			isDev: process.env.NODE_ENV !== "production",
			isLightTheme: true,
			entrypointUrl: "http://localhost:3000/ask-the-llm",
			//@ts-ignore
			clientUrl: "http://localhost:6123/bootstrap.js",
		}),
	]
});
