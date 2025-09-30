import React, { useState, useEffect } from "react";
import ChatPanel from "./components/ChatPanel";
import ContentPanel from "./components/ContentPanel";
import { SelectElement } from "./types/SelectElement";

// Types for compatibility with ChatPanel
interface ChatMessage {
	id: string;
	text: string;
	sender: "user" | "assistant";
	status?: 'sending' | 'completed' | 'error';
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
	};
}

interface ChatResponse {
	response: string;
	status: string;
	iterations: number;
	toolCalls?: Array<{
		tool: string;
		parameters: any;
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
			text: message,
			sender: 'user',
			status: 'completed'
		};

		// Add assistant loading message
		const assistantMessage: ChatMessage = {
			id: (Date.now() + 1).toString(),
			text: 'Thinking...',
			sender: 'assistant',
			status: 'sending'
		};

		setMessages(prev => [...prev, userMessage, assistantMessage]);
		setMessage('');
		setIsLoading(true);

		try {
			// Prepare the API request
			const chatRequest: ChatRequest = {
				messages: [...messages.map(m => m.text), message],
			};

			// Add selected element if available
			console.log('[Client] Selected element:', selectedElement);
			
			if (selectedElement) {
				chatRequest.selectedElement = {};
				
				// Add source location if available and resolved
				if (selectedElement.reactComponent?.sourceLocation?.status === 'resolved') {
					console.log('[Client] Adding source location to request:', selectedElement.reactComponent.sourceLocation);
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
					chatRequest.selectedElement.componentName = selectedElement.reactComponent.name;
				}
				
				console.log('[Client] Selected element debug info:', {
					hasReactComponent: !!selectedElement.reactComponent,
					sourceLocationStatus: selectedElement.reactComponent?.sourceLocation?.status,
					sourceLocation: selectedElement.reactComponent?.sourceLocation,
					selector: selectedElement.selector,
					componentName: selectedElement.reactComponent?.name
				});
			}

			console.log('[Client] Final chat request:', chatRequest);

			// Make streaming API call
			const response = await fetch('/api/ask-the-llm/chat', {
				method: 'POST',
				headers: {
					'Content-Type': 'application/json',
					'Accept': 'text/event-stream',
					'X-Stream-Request': 'true',
				},
				body: JSON.stringify(chatRequest),
			});

			console.log('[Client] Response headers:', Object.fromEntries(response.headers.entries()));
			console.log('[Client] Response content-type:', response.headers.get('content-type'));

			if (!response.ok) {
				throw new Error(`HTTP ${response.status}`);
			}

			// Check if we actually got a streaming response
			const contentType = response.headers.get('content-type');
			if (contentType !== 'text/event-stream') {
				console.log('[Client] Not a streaming response, falling back to JSON');
				const data: ChatResponse = await response.json();
				console.log('[Client] Received JSON response:', data);
				
				// Handle as regular JSON response
				let responseText = data.response;
				if (data.toolCalls && data.toolCalls.length > 0) {
					const toolCallSummary = data.toolCalls.map((tc, index) => {
						const params = Object.entries(tc.parameters)
							.map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
							.join(', ');
						return `${index + 1}. 🔧 ${tc.tool}(${params})`;
					}).join('\n');
					responseText = `${responseText}\n\n**Tools executed (${data.toolCalls.length}):**\n${toolCallSummary}`;
				}

				setMessages(prev => 
					prev.map(m => 
						m.id === assistantMessage.id 
							? { 
								...m, 
								text: responseText, 
								status: 'completed' as const 
							}
							: m
					)
				);
				return;
			}

			console.log('[Client] Got streaming response, processing...');

			// Handle streaming response
			const reader = response.body?.getReader();
			const decoder = new TextDecoder();

			if (!reader) {
				throw new Error('No response body');
			}

			let buffer = '';
			let toolCallsLog: string[] = [];

			while (true) {
				const { done, value } = await reader.read();
				
				if (done) break;

				buffer += decoder.decode(value, { stream: true });
				const lines = buffer.split('\n');
				buffer = lines.pop() || '';

				for (const line of lines) {
					if (line.startsWith('data: ')) {
						try {
							const data = JSON.parse(line.slice(6));
							console.log('[Client] Stream event:', data);

							switch (data.type) {
								case 'status':
									// Update assistant message with status
									setMessages(prev => 
										prev.map(m => 
											m.id === assistantMessage.id 
												? { ...m, text: data.message }
												: m
										)
									);
									break;

								case 'tool_start':
									toolCallsLog.push(`🔧 Starting ${data.tools.length} tools...`);
									setMessages(prev => 
										prev.map(m => 
											m.id === assistantMessage.id 
												? { ...m, text: `${data.message}\n\n${toolCallsLog.join('\n')}` }
												: m
										)
									);
									break;

								case 'tool_executing':
									const params = Object.entries(data.parameters)
										.map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
										.join(', ');
									toolCallsLog.push(`⚡ Executing ${data.tool}(${params})`);
									setMessages(prev => 
										prev.map(m => 
											m.id === assistantMessage.id 
												? { ...m, text: `Executing tools...\n\n${toolCallsLog.join('\n')}` }
												: m
										)
									);
									break;

								case 'tool_completed':
									const completedParams = Object.entries(data.parameters)
										.map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
										.join(', ');
									toolCallsLog.push(`✅ ${data.tool}(${completedParams}) - ${data.executionTime}ms`);
									if (data.result) {
										toolCallsLog.push(`   Result: ${data.result}`);
									}
									setMessages(prev => 
										prev.map(m => 
											m.id === assistantMessage.id 
												? { ...m, text: `Processing...\n\n${toolCallsLog.join('\n')}` }
												: m
										)
									);
									break;

								case 'final_response':
									// Update with final response
									const finalText = `${data.response}\n\n**Tools executed:**\n${toolCallsLog.join('\n')}`;
									setMessages(prev => 
										prev.map(m => 
											m.id === assistantMessage.id 
												? { 
													...m, 
													text: finalText, 
													status: 'completed' as const 
												}
												: m
										)
									);
									break;

								case 'complete':
									console.log('[Client] Stream completed');
									break;

								case 'error':
									throw new Error(data.error);
							}
						} catch (parseError) {
							console.error('[Client] Failed to parse stream data:', parseError);
						}
					}
				}
			}

		} catch (error) {
			console.error('Chat API error:', error);
			
			// Update the assistant message with error
			setMessages(prev => 
				prev.map(m => 
					m.id === assistantMessage.id 
						? { 
							...m, 
							text: `Error: ${error instanceof Error ? error.message : 'Unknown error occurred'}`, 
							status: 'error' as const 
						}
						: m
				)
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
