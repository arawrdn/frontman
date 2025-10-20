import type React from "react";
import { useEffect, useState } from "react";
import ChatPanel from "./components/ChatPanel";
import ContentPanel from "./components/ContentPanel";
import type { SelectElement } from "./types/SelectElement";

// Types for compatibility with ChatPanel
export interface ChangeProposal {
	filePath: string;
	description: string;
	changeType: "create" | "modify" | "delete";
	currentExists: boolean;
	currentLines: number;
	proposedLines: number;
	lineDiff: number;
	proposedContent: string;
	diff: string;
	preview: {
		currentContent: string;
		proposedContent: string;
	};
}

export interface ProposalState {
	proposal: ChangeProposal;
	status: "pending" | "accepted" | "rejected" | "applying" | "error";
	errorMessage?: string;
}

interface ToolCall {
	tool: string;
	parameters: Record<string, unknown>;
	result?: string;
	executionTime?: number;
	status: "executing" | "completed";
	// Add proposal state for propose_change tools
	proposalState?: ProposalState;
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

// API request types
interface ChatRequest {
	message: string;
	selectedElement?: {
		sourceLocation?: {
			file: string;
			line: number;
		};
		selector?: string;
		componentName?: string;
	} | null;
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

	// SSE connection hook
	useEffect(() => {
		console.log("[SSE] Connecting to /api/ask-the-llm/chat-sse...");
		const eventSource = new EventSource("/api/ask-the-llm/chat-sse");

		eventSource.onopen = () => {
			console.log("[SSE] Connection opened");
		};

		eventSource.onmessage = (event) => {
			console.log("[SSE] Message received:", event.data);
		};

		eventSource.onerror = (error) => {
			console.error("[SSE] Error occurred:", error);
			eventSource.close();
		};

		// Cleanup on unmount
		return () => {
			console.log("[SSE] Closing connection");
			eventSource.close();
		};
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
				message: message,
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

			console.log("[Client] Processing streaming response...");

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
								case "reasoning_chunk":
									// Append reasoning content to assistant message
									setMessages((prev) =>
										prev.map((m) =>
											m.id === assistantMessage.id
												? {
														...m,
														content: (m.content || "") + data.content,
														statusMessage: "Thinking...",
													}
												: m,
										),
									);
									break;

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

								case "strategy":
									// Display the task strategy to the user
									setMessages((prev) =>
										prev.map((m) =>
											m.id === assistantMessage.id
												? {
														...m,
														content: data.message,
														statusMessage: "Strategy planned",
													}
												: m,
										),
									);
									break;

								case "tool_start":
									setMessages((prev) =>
										prev.map((m) => {
											if (m.id !== assistantMessage.id) return m;

											// APPEND new tools to existing toolCalls, don't replace
											const existingToolCalls = m.toolCalls || [];
											const newTools = data.tools.map(
												(t: {
													name: string;
													parameters: Record<string, unknown>;
												}) => ({
													tool: t.name,
													parameters: t.parameters,
													status: "executing" as const,
												}),
											);

											return {
												...m,
												statusMessage: data.message,
												toolCalls: [...existingToolCalls, ...newTools],
											};
										}),
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
									console.log("[DEBUG] tool_completed event received:", {
										tool: data.tool,
										resultLength: data.result?.length,
										resultPreview: data.result?.substring(0, 100),
									});

									setMessages((prev) =>
										prev.map((m) => {
											if (m.id !== assistantMessage.id) return m;

											const updatedToolCalls = [...(m.toolCalls || [])];
											console.log(
												"[DEBUG] Current toolCalls:",
												updatedToolCalls.map((tc) => ({
													tool: tc.tool,
													status: tc.status,
												})),
											);

											const toolIndex = updatedToolCalls.findIndex(
												(tc) => tc.tool === data.tool,
											);
											console.log(
												"[DEBUG] Found toolIndex:",
												toolIndex,
												"for tool:",
												data.tool,
											);

											if (toolIndex >= 0) {
												updatedToolCalls[toolIndex] = {
													...updatedToolCalls[toolIndex],
													status: "completed" as const,
													result: data.result,
													executionTime: data.executionTime,
												};

												// NEW: Parse propose_change results
												if (data.tool === "propose_change") {
													console.log(
														"[DEBUG] Attempting to parse propose_change result...",
													);
													try {
														const proposal: ChangeProposal = JSON.parse(
															data.result,
														);
														console.log(
															"[DEBUG] Successfully parsed proposal:",
															{
																filePath: proposal.filePath,
																changeType: proposal.changeType,
																hasDiff: !!proposal.diff,
																diffLength: proposal.diff?.length,
																diffPreview: proposal.diff?.substring(0, 100),
															},
														);
														updatedToolCalls[toolIndex].proposalState = {
															proposal,
															status: "pending",
														};
														console.log(
															"[DEBUG] proposalState set successfully",
														);
													} catch (e) {
														console.error(
															"[DEBUG] Failed to parse proposal:",
															e,
														);
														console.error(
															"[DEBUG] Raw result was:",
															data.result,
														);
													}
												}
											} else {
												console.warn(
													"[DEBUG] toolIndex not found! data.tool =",
													data.tool,
													"available tools:",
													updatedToolCalls.map((tc) => tc.tool),
												);
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

	const handleAcceptProposal = async (messageId: string, toolIndex: number) => {
		const message = messages.find((m) => m.id === messageId);
		if (!message?.toolCalls?.[toolIndex]?.proposalState) return;

		const { proposal } = message.toolCalls[toolIndex].proposalState!;

		// Update status to "applying"
		setMessages((prev) =>
			prev.map((m) =>
				m.id === messageId
					? {
							...m,
							toolCalls: m.toolCalls?.map((tc, idx) =>
								idx === toolIndex && tc.proposalState
									? {
											...tc,
											proposalState: {
												...tc.proposalState,
												status: "applying" as const,
											},
										}
									: tc,
							),
						}
					: m,
			),
		);

		try {
			// Call apply_patch API
			const response = await fetch("/api/ask-the-llm/apply-patch", {
				method: "POST",
				headers: { "Content-Type": "application/json" },
				body: JSON.stringify({
					filePath: proposal.filePath,
					patch: proposal.proposedContent,
					description: proposal.description,
				}),
			});

			const result = await response.json();

			if (response.ok && result.success) {
				// Mark as accepted
				setMessages((prev) =>
					prev.map((m) =>
						m.id === messageId
							? {
									...m,
									toolCalls: m.toolCalls?.map((tc, idx) =>
										idx === toolIndex && tc.proposalState
											? {
													...tc,
													proposalState: {
														...tc.proposalState,
														status: "accepted" as const,
													},
												}
											: tc,
									),
								}
							: m,
					),
				);
			} else {
				throw new Error(result.error || "Failed to apply patch");
			}
		} catch (error) {
			// Mark as error
			setMessages((prev) =>
				prev.map((m) =>
					m.id === messageId
						? {
								...m,
								toolCalls: m.toolCalls?.map((tc, idx) =>
									idx === toolIndex && tc.proposalState
										? {
												...tc,
												proposalState: {
													...tc.proposalState,
													status: "error" as const,
													errorMessage:
														error instanceof Error
															? error.message
															: "Unknown error",
												},
											}
										: tc,
								),
							}
						: m,
				),
			);
		}
	};

	const handleRejectProposal = (messageId: string, toolIndex: number) => {
		setMessages((prev) =>
			prev.map((m) =>
				m.id === messageId
					? {
							...m,
							toolCalls: m.toolCalls?.map((tc, idx) =>
								idx === toolIndex && tc.proposalState
									? {
											...tc,
											proposalState: {
												...tc.proposalState,
												status: "rejected" as const,
											},
										}
									: tc,
							),
						}
					: m,
			),
		);
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
				onAcceptProposal={handleAcceptProposal}
				onRejectProposal={handleRejectProposal}
			/>

			<ContentPanel iframeUrl={iframeUrl} />
		</div>
	);
};

export default SplitLayoutWidget;
