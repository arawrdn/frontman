import * as vite from "vite";
import { askTheLlmPlugin } from "@ask-the-llm/vite-plugin";

export default vite.defineConfig({
	server: {
		port: 6123,
	},
	plugins: [
		askTheLlmPlugin({
			isDev: process.env.NODE_ENV !== "production",
			isLightTheme: true,
			entrypointUrl: "http://localhost:3000/api/ask-the-llm",
			//@ts-ignore
			clientUrl: "http://localhost:6123/bootstrap.js",
		}),
	]
});
