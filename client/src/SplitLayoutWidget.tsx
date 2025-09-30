import React, { useState, useEffect } from "react";
import ChatPanel from "./components/ChatPanel";
import ContentPanel from "./components/ContentPanel";
import { SelectElement } from "./types/SelectElement";

// Types for compatibility with ChatPanel
interface ChatMessage {
	id: string;
	text: string;
	sender: "user" | "assistant";
}

const SplitLayoutWidget: React.FC = () => {
	const [message, setMessage] = useState("");
	const [iframeUrl, setIframeUrl] = useState("");
	const [selectedElement, setSelectedElement] = useState<SelectElement | null>(
		null,
	);
	const [messages, setMessages] = useState<ChatMessage[]>([]); // Conversation history

	useEffect(() => {
		// Get the origin (protocol + hostname + port) without the path
		const currentUrl = new URL(window.location.href);
		const originUrl = `${currentUrl.protocol}//${currentUrl.host}`;
		setIframeUrl(originUrl);
	}, []);

	const handleSendMessage = () => {
		// Placeholder for send message functionality
		console.log("Send message:", message);
		// Add message to conversation history
		if (message.trim()) {
			const newMessage: ChatMessage = {
				id: Date.now().toString(),
				text: message,
				sender: "user",
			};
			setMessages((prev) => [...prev, newMessage]);
			setMessage("");
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
