import type React from "react";
import { useCallback, useEffect, useState } from "react";
import ChatPanel from "./components/ChatPanel";
import ContentPanel from "./components/ContentPanel";
import type { SelectElement } from "./types/SelectElement";
import { useSSE } from "./hooks/useSSE"
import { Message, normalizeId, normalizePart } from "./types/Message";

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

	const handleSSEMessage = useCallback((msg: Message) => {
		console.log("[SSE] Message received:", msg);

		// Normalize the message ID from ReScript format
		const messageId = normalizeId(msg.messageId);

		setMessages((prev) => {
			// Check if we already have a message with this ID
			const existingIndex = prev.findIndex((m) => m.id === messageId);

			// Safety check for parts array
			if (!msg.parts || !Array.isArray(msg.parts)) {
				console.warn("[SSE] Message has no parts array:", msg);
				return prev;
			}

			// Normalize all parts from ReScript TAG/_0 format
			const normalizedParts = msg.parts.map(normalizePart);

			// Build content from text parts
			let content = "";
			const textParts = normalizedParts.filter((p) => p.type === "text");

			// Filter out thinking content (metadata.isThinking === true)
			const nonThinkingParts = textParts.filter(
				(p) => !p.metadata?.isThinking
			);

			// Use non-thinking parts if available, otherwise use all text
			const partsToUse = nonThinkingParts.length > 0 ? nonThinkingParts : textParts;

			for (const part of partsToUse) {
				if (part.type === "text") {
					content += part.text;
				}
			}

			// Extract tool calls from parts
			const toolCalls: ToolCall[] = [];
			for (const part of normalizedParts) {
				if (part.type === "toolUse") {
					toolCalls.push({
						tool: part.toolName,
						parameters: part.args as Record<string, unknown>,
						status: "executing",
					});
				} else if (part.type === "toolResult") {
					// Find matching tool call and update it
					const toolIndex = toolCalls.findIndex(
						(tc) => tc.tool === part.toolName
					);
					if (toolIndex >= 0) {
						toolCalls[toolIndex] = {
							...toolCalls[toolIndex],
							status: "completed",
							result: typeof part.result === "string"
								? part.result
								: JSON.stringify(part.result),
						};
					}
				}
			}

			if (existingIndex >= 0) {
				// Update existing message
				return prev.map((m, idx) => {
					if (idx !== existingIndex) return m;

					return {
						...m,
						content,
						toolCalls: toolCalls.length > 0 ? toolCalls : m.toolCalls,
						status: "completed" as const,
						statusMessage: undefined,
					};
				});
			} else {
				// Create new message
				const newMessage: ChatMessage = {
					id: messageId,
					content,
					sender: msg.role === "user" ? "user" : "assistant",
					status: "completed",
					toolCalls: toolCalls.length > 0 ? toolCalls : undefined,
				};

				return [...prev, newMessage];
			}
		});
	}, []); // Empty deps - setMessages is stable

	useSSE(handleSSEMessage)

	const handleSendMessage = async () => {
		if (!message.trim() || isLoading) return;

		// Add user message to conversation history
		const userMessage: ChatMessage = {
			id: Date.now().toString(),
			content: message,
			sender: "user",
			status: "completed",
		};

		setMessages((prev) => [...prev, userMessage]);
		setMessage("");
		setIsLoading(true);

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
