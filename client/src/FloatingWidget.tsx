import React, { useState } from 'react';
import * as Dialog from '@radix-ui/react-dialog';
import { ChatBubbleIcon, Cross2Icon } from '@radix-ui/react-icons';
import { createOpenAIClient } from './services/openai';

interface Message {
  id: string;
  role: 'user' | 'assistant';
  content: string;
  timestamp: number;
}

const FloatingWidget: React.FC = () => {
  const [message, setMessage] = useState('');
  const [messages, setMessages] = useState<Message[]>([]);
  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const [openAIClient] = useState(() => {
    try {
      return createOpenAIClient();
    } catch {
      return null;
    }
  });

  const handleSendMessage = async () => {
    if (!message.trim() || isLoading || !openAIClient) return;

    const currentMessage = message.trim();
    const userMessage: Message = {
      id: `user-${Date.now()}`,
      role: 'user',
      content: currentMessage,
      timestamp: Date.now(),
    };

    setMessages(prev => [...prev, userMessage]);
    setMessage('');
    setIsLoading(true);
    setError(null);

    try {
      const response = await openAIClient.createResponse({
        model: 'gpt-4o',
        input: currentMessage,
        max_output_tokens: 1000,
        temperature: 0.7,
      });

      const assistantContent = response.output
        .find(item => item.type === 'message')
        ?.content.find(content => content.type === 'output_text')
        ?.text || 'No response received';

      const assistantMessage: Message = {
        id: response.id,
        role: 'assistant',
        content: assistantContent,
        timestamp: Date.now(),
      };

      setMessages(prev => [...prev, assistantMessage]);
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Failed to send message');
    } finally {
      setIsLoading(false);
    }
  };
  return (
    <div
      style={{
        position: 'fixed',
        bottom: '20px',
        left: '20px',
        zIndex: 999999,
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif'
      }}
    >
      <Dialog.Root>
        <Dialog.Trigger asChild>
          <button
            style={{
              width: '60px',
              height: '60px',
              borderRadius: '50%',
              backgroundColor: '#3b82f6',
              border: 'none',
              color: 'white',
              cursor: 'pointer',
              display: 'flex',
              alignItems: 'center',
              justifyContent: 'center',
              boxShadow: '0 4px 12px rgba(0, 0, 0, 0.2)',
              transition: 'all 0.2s ease',
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.transform = 'scale(1.1)';
              e.currentTarget.style.backgroundColor = '#2563eb';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.transform = 'scale(1)';
              e.currentTarget.style.backgroundColor = '#3b82f6';
            }}
            title="Open Chat"
          >
            <ChatBubbleIcon width={24} height={24} />
          </button>
        </Dialog.Trigger>

        <Dialog.Portal>
          <Dialog.Overlay
            style={{
              backgroundColor: 'rgba(0, 0, 0, 0.5)',
              position: 'fixed',
              inset: 0,
              zIndex: 999998,
            }}
          />
          <Dialog.Content
            style={{
              backgroundColor: 'white',
              borderRadius: '12px',
              boxShadow: '0 10px 25px rgba(0, 0, 0, 0.2)',
              position: 'fixed',
              top: '50%',
              left: '50%',
              transform: 'translate(-50%, -50%)',
              width: '90vw',
              maxWidth: '400px',
              maxHeight: '85vh',
              padding: '24px',
              zIndex: 999999,
              outline: 'none',
            }}
          >
            <Dialog.Title
              style={{
                margin: 0,
                fontSize: '18px',
                fontWeight: '600',
                color: '#1f2937',
                marginBottom: '16px',
              }}
            >
              Ask the LLM
            </Dialog.Title>

            <Dialog.Description
              style={{
                margin: 0,
                color: '#6b7280',
                fontSize: '14px',
                lineHeight: '1.5',
                marginBottom: '20px',
              }}
            >
              Chat with OpenAI to get help with your questions.
            </Dialog.Description>

            {/* Error Display */}
            {error && (
              <div style={{
                padding: '12px',
                backgroundColor: '#fef2f2',
                border: '1px solid #fecaca',
                borderRadius: '8px',
                color: '#dc2626',
                fontSize: '14px',
                marginBottom: '16px',
              }}>
                Error: {error}
              </div>
            )}

            {/* Conversation Area */}
            <div style={{
              minHeight: '200px',
              maxHeight: '300px',
              overflowY: 'auto',
              marginBottom: '20px',
              padding: '12px',
              border: '1px solid #e5e7eb',
              borderRadius: '8px',
              backgroundColor: '#f9fafb',
            }}>
              {messages.length === 0 ? (
                <div style={{
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  height: '100%',
                  color: '#6b7280',
                  fontSize: '14px',
                  fontStyle: 'italic',
                }}>
                  No messages yet. Start a conversation!
                </div>
              ) : (
                <div style={{ display: 'flex', flexDirection: 'column', gap: '12px' }}>
                  {messages.map((msg) => (
                    <div
                      key={msg.id}
                      style={{
                        backgroundColor: msg.role === 'user' ? '#3b82f6' : '#374151',
                        color: 'white',
                        padding: '8px 12px',
                        borderRadius: '8px',
                        maxWidth: '85%',
                        alignSelf: msg.role === 'user' ? 'flex-end' : 'flex-start',
                        fontSize: '13px',
                        lineHeight: '1.4',
                      }}
                    >
                      {msg.content}
                    </div>
                  ))}
                  {isLoading && (
                    <div style={{
                      backgroundColor: '#374151',
                      color: '#9ca3af',
                      padding: '8px 12px',
                      borderRadius: '8px',
                      maxWidth: '85%',
                      fontSize: '13px',
                      fontStyle: 'italic',
                    }}>
                      Thinking...
                    </div>
                  )}
                </div>
              )}
            </div>

            <div style={{ marginBottom: '20px' }}>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                style={{
                  width: '100%',
                  minHeight: '100px',
                  padding: '12px',
                  border: '1px solid #d1d5db',
                  borderRadius: '8px',
                  fontSize: '14px',
                  resize: 'vertical',
                  outline: 'none',
                  boxSizing: 'border-box',
                }}
                placeholder="Type your question here..."
                disabled={isLoading}
              />
            </div>

            <div style={{ display: 'flex', gap: '8px', justifyContent: 'flex-end' }}>
              <button
                onClick={handleSendMessage}
                disabled={!message.trim() || isLoading}
                style={{
                  padding: '8px 16px',
                  backgroundColor: (!message.trim() || isLoading) ? '#9ca3af' : '#3b82f6',
                  color: 'white',
                  border: 'none',
                  borderRadius: '6px',
                  fontSize: '14px',
                  cursor: (!message.trim() || isLoading) ? 'not-allowed' : 'pointer',
                  transition: 'background-color 0.2s',
                }}
                onMouseEnter={(e) => {
                  if (!isLoading && message.trim()) {
                    e.currentTarget.style.backgroundColor = '#2563eb';
                  }
                }}
                onMouseLeave={(e) => {
                  if (!isLoading && message.trim()) {
                    e.currentTarget.style.backgroundColor = '#3b82f6';
                  }
                }}
              >
                {isLoading ? 'Sending...' : 'Send'}
              </button>
            </div>

            <Dialog.Close asChild>
              <button
                style={{
                  position: 'absolute',
                  top: '12px',
                  right: '12px',
                  width: '32px',
                  height: '32px',
                  border: 'none',
                  backgroundColor: 'transparent',
                  cursor: 'pointer',
                  borderRadius: '50%',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  color: '#6b7280',
                }}
                aria-label="Close"
                onMouseEnter={(e) => {
                  e.currentTarget.style.backgroundColor = '#f3f4f6';
                }}
                onMouseLeave={(e) => {
                  e.currentTarget.style.backgroundColor = 'transparent';
                }}
              >
                <Cross2Icon width={16} height={16} />
              </button>
            </Dialog.Close>
          </Dialog.Content>
        </Dialog.Portal>
      </Dialog.Root>
    </div>
  );
};

export default FloatingWidget;