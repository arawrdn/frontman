import type React from "react";
import { useEffect, useState } from "react";
import ChatPanel from "./components/ChatPanel";
import ContentPanel from "./components/ContentPanel";
import type { SelectElement } from "./types/SelectElement";

// Types for compatibility with ChatPanel
interface ToolCall {
	tool: string;
	parameters: Record<string, unknown>;
	result?: string;
	executionTime?: number;
	status: "executing" | "completed";
}

interface ChatMessage {
	id: string;
	content: string; // Clean content for LLM (data layer)
	sender: "user" | "assistant";
	status?: "sending" | "completed" | "error";

	// Presentation metadata
	toolCalls?: ToolCall[];
	statusMessage?: string;
}

// API request/response types
interface ChatRequest {
	messages: string[];
	selectedElement?: {
		sourceLocation?: {
			file: string;
			line: number;
		};
		selector?: string;
		componentName?: string;
	} | null;
}

interface ChatResponse {
	response: string;
	status: string;
	iterations: number;
	toolCalls?: Array<{
		tool: string;
		parameters: Record<string, unknown>;
		result: string;
	}>;
	error?: string;
	details?: string;
}

const SplitLayoutWidget: React.FC = () => {
	const [message, setMessage] = useState("");
	const [iframeUrl, setIframeUrl] = useState("");
	const [selectedElement, setSelectedElement] = useState<SelectElement | null>(
		null,
	);
	const [messages, setMessages] = useState<ChatMessage[]>([]); // Conversation history
	const [isLoading, setIsLoading] = useState(false);

	useEffect(() => {
		const currentUrl = new URL(window.location.href);
		const originUrl = `${currentUrl.protocol}//${currentUrl.host}`;
		setIframeUrl(originUrl);
	}, []);

	const handleSendMessage = async () => {
		if (!message.trim() || isLoading) return;

		// Add user message to conversation history
		const userMessage: ChatMessage = {
			id: Date.now().toString(),
			content: message,
			sender: "user",
			status: "completed",
		};

		// Add assistant loading message
		const assistantMessage: ChatMessage = {
			id: (Date.now() + 1).toString(),
			content: "",
			sender: "assistant",
			status: "sending",
			statusMessage: "Thinking...",
			toolCalls: [],
		};

		setMessages((prev) => [...prev, userMessage, assistantMessage]);
		setMessage("");
		setIsLoading(true);

		try {
			// Prepare the API request
			const chatRequest: ChatRequest = {
				messages: [...messages.map((m) => m.content), message],
			};

			// Add selected element if available
			console.log("[Client] Selected element:", selectedElement);

			if (selectedElement) {
				chatRequest.selectedElement = {};

				// Add source location if available and resolved
				if (
					selectedElement.reactComponent?.sourceLocation?.status === "resolved"
				) {
					console.log(
						"[Client] Adding source location to request:",
						selectedElement.reactComponent.sourceLocation,
					);
					chatRequest.selectedElement.sourceLocation = {
						file: selectedElement.reactComponent.sourceLocation.file,
						line: selectedElement.reactComponent.sourceLocation.line,
					};
				}

				// Always add selector as fallback
				if (selectedElement.selector) {
					chatRequest.selectedElement.selector = selectedElement.selector;
				}

				// Add component name if available
				if (selectedElement.reactComponent?.name) {
					chatRequest.selectedElement.componentName =
						selectedElement.reactComponent.name;
				}

				console.log("[Client] Selected element debug info:", {
					hasReactComponent: !!selectedElement.reactComponent,
					sourceLocationStatus:
						selectedElement.reactComponent?.sourceLocation?.status,
					sourceLocation: selectedElement.reactComponent?.sourceLocation,
					selector: selectedElement.selector,
					componentName: selectedElement.reactComponent?.name,
				});
			}

			console.log("[Client] Final chat request:", chatRequest);

			// Make streaming API call
			const response = await fetch("/api/ask-the-llm/chat", {
				method: "POST",
				headers: {
					"Content-Type": "application/json",
					Accept: "text/event-stream",
					"X-Stream-Request": "true",
				},
				body: JSON.stringify(chatRequest),
			});

			console.log(
				"[Client] Response headers:",
				Object.fromEntries(response.headers.entries()),
			);
			console.log(
				"[Client] Response content-type:",
				response.headers.get("content-type"),
			);

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}

			// Check if we actually got a streaming response
			const contentType = response.headers.get("content-type");
			if (contentType !== "text/event-stream") {
				console.log("[Client] Not a streaming response, falling back to JSON");
				const data: ChatResponse = await response.json();
				console.log("[Client] Received JSON response:", data);

				// Handle as regular JSON response
				const toolCalls: ToolCall[] = (data.toolCalls || []).map((tc) => ({
					tool: tc.tool,
					parameters: tc.parameters,
					result: tc.result,
					status: "completed" as const,
				}));

				setMessages((prev) =>
					prev.map((m) =>
						m.id === assistantMessage.id
							? {
									...m,
									content: data.response,
									status: "completed" as const,
									toolCalls,
									statusMessage: undefined,
								}
							: m,
					),
				);
				return;
			}

			console.log("[Client] Got streaming response, processing...");

			// Handle streaming response
			const reader = response.body?.getReader();
			const decoder = new TextDecoder();

			if (!reader) {
				throw new Error("No response body");
			}

			let buffer = "";

			while (true) {
				const { done, value } = await reader.read();

				if (done) break;

				buffer += decoder.decode(value, { stream: true });
				const lines = buffer.split("\n");
				buffer = lines.pop() || "";

				for (const line of lines) {
					if (line.startsWith("data: ")) {
						try {
							const data = JSON.parse(line.slice(6));
							console.log("[Client] Stream event:", data);

							switch (data.type) {
								case "status":
									// Update assistant message with status
									setMessages((prev) =>
										prev.map((m) =>
											m.id === assistantMessage.id
												? { ...m, statusMessage: data.message }
												: m,
										),
									);
									break;

								case "tool_start":
									setMessages((prev) =>
										prev.map((m) =>
											m.id === assistantMessage.id
												? {
														...m,
														statusMessage: data.message,
														toolCalls: data.tools.map((t: { name: string; parameters: Record<string, unknown> }) => ({
															tool: t.name,
															parameters: t.parameters,
															status: "executing" as const,
														})),
													}
												: m,
										),
									);
									break;

								case "tool_executing": {
									setMessages((prev) =>
										prev.map((m) => {
											if (m.id !== assistantMessage.id) return m;

											const updatedToolCalls = [...(m.toolCalls || [])];
											const existingIndex = updatedToolCalls.findIndex(
												(tc) => tc.tool === data.tool,
											);

											if (existingIndex >= 0) {
												updatedToolCalls[existingIndex] = {
													...updatedToolCalls[existingIndex],
													status: "executing" as const,
												};
											} else {
												updatedToolCalls.push({
													tool: data.tool,
													parameters: data.parameters,
													status: "executing" as const,
												});
											}

											return {
												...m,
												toolCalls: updatedToolCalls,
												statusMessage: "Executing tools...",
											};
										}),
									);
									break;
								}

								case "tool_completed": {
									setMessages((prev) =>
										prev.map((m) => {
											if (m.id !== assistantMessage.id) return m;

											const updatedToolCalls = [...(m.toolCalls || [])];
											const toolIndex = updatedToolCalls.findIndex(
												(tc) => tc.tool === data.tool,
											);

											if (toolIndex >= 0) {
												updatedToolCalls[toolIndex] = {
													...updatedToolCalls[toolIndex],
													status: "completed" as const,
													result: data.result,
													executionTime: data.executionTime,
												};
											}

											return {
												...m,
												toolCalls: updatedToolCalls,
												statusMessage: "Processing...",
											};
										}),
									);
									break;
								}

								case "final_response": {
									// Update with final response
									setMessages((prev) =>
										prev.map((m) =>
											m.id === assistantMessage.id
												? {
														...m,
														content: data.response,
														status: "completed" as const,
														statusMessage: undefined,
													}
												: m,
										),
									);
									break;
								}

								case "complete":
									console.log("[Client] Stream completed");
									break;

								case "error":
									throw new Error(data.error);
							}
						} catch (parseError) {
							console.error(
								"[Client] Failed to parse stream data:",
								parseError,
							);
						}
					}
				}
			}
		} catch (error) {
			console.error("Chat API error:", error);

			// Update the assistant message with error
			setMessages((prev) =>
				prev.map((m) =>
					m.id === assistantMessage.id
						? {
								...m,
								content: `Error: ${error instanceof Error ? error.message : "Unknown error occurred"}`,
								status: "error" as const,
								statusMessage: undefined,
							}
						: m,
				),
			);
		} finally {
			setIsLoading(false);
		}
	};

	const handleElementSelected = (element: SelectElement) => {
		console.log("Element selected:", element);
		console.log("Source location:", element.reactComponent?.sourceLocation);
		console.trace("handleElementSelected called from:");
		setSelectedElement(element);
	};

	const handleClearSelection = () => {
		setSelectedElement(null);
	};

	const handleLearnMoreClick = () => {
		console.log("Learn more clicked");
		// Add your learn more logic here
	};

	const handleSettingsClick = () => {
		console.log("Settings clicked");
		// Add your settings logic here
	};

	return (
		<div
			style={{
				display: "flex",
				height: "100vh",
				width: "100vw",
				fontFamily:
					'-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
				position: "fixed",
				top: 0,
				left: 0,
				zIndex: 999999,
				backgroundColor: "#fff",
			}}
		>
			<ChatPanel
				message={message}
				onMessageChange={setMessage}
				onSendMessage={handleSendMessage}
				messages={messages}
				onLearnMoreClick={handleLearnMoreClick}
				onSettingsClick={handleSettingsClick}
				onElementSelected={handleElementSelected}
				selectedElement={selectedElement}
				onClearSelection={handleClearSelection}
			/>

			<ContentPanel iframeUrl={iframeUrl} />
		</div>
	);
};

export default SplitLayoutWidget;
