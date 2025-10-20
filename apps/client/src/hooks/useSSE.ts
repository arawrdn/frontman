import { useEffect } from "react"

import type { Message } from "../types/Message"

export const useSSE = (newEventCallback: (msg: Message)=> void) => {
    // SSE connection hook
    return useEffect(() => {
        console.log("[SSE] Connecting to /api/ask-the-llm/chat-sse...");
        const eventSource = new EventSource("/api/ask-the-llm/chat-sse");

        eventSource.onopen = () => {
            console.log("[SSE] Connection opened");
        };

        eventSource.onmessage = (event) => {
            console.log("[SSE] Message received:", event.data);
            const msg: Message = JSON.parse(event.data)
            console.log("Parsed message", event.data)
            newEventCallback(msg)
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
    }, [newEventCallback]);
}
