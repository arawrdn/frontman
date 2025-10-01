import React from 'react';

interface ChatMessagesProps {
  title?: string;
  subtitle?: string;
  messages?: Array<{
    id: string;
    content: string;
    sender: 'user' | 'assistant';
    status?: 'sending' | 'completed' | 'error';
    statusMessage?: string;
    toolCalls?: Array<{
      tool: string;
      parameters: Record<string, unknown>;
      result?: string;
      executionTime?: number;
      status: "executing" | "completed";
    }>;
  }>;
}

const ChatMessages: React.FC<ChatMessagesProps> = ({
  title = "What do you want to build?",
  subtitle = "Type a message below to begin",
  messages = []
}) => {
  const hasMessages = messages.length > 0;

  if (hasMessages) {
    return (
      <div
        style={{
          flex: 1,
          padding: '20px',
          overflowY: 'auto',
          display: 'flex',
          flexDirection: 'column',
          gap: '16px'
        }}
      >
        {messages.map((message) => {
          // Determine what to display
          let displayContent = message.content;

          // If still sending and no content, show status message
          if (message.status === 'sending' && !message.content && message.statusMessage) {
            displayContent = message.statusMessage;
          }

          return (
            <div
              key={message.id}
              style={{
                padding: '12px',
                borderRadius: '8px',
                backgroundColor: message.sender === 'user' ? '#374151' : '#1f2937',
                color: '#f3f4f6',
                fontSize: '14px',
                lineHeight: '1.5',
                opacity: message.status === 'sending' ? 0.7 : 1,
                border: message.status === 'error' ? '1px solid #ef4444' : 'none'
              }}
            >
              <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
                {message.status === 'sending' && (
                  <div style={{
                    width: '12px',
                    height: '12px',
                    border: '2px solid #9ca3af',
                    borderTop: '2px solid #60a5fa',
                    borderRadius: '50%',
                    animation: 'spin 1s linear infinite'
                  }} />
                )}
                {message.status === 'error' && (
                  <span style={{ color: '#ef4444', fontSize: '12px' }}>⚠</span>
                )}
                <div style={{ flex: 1 }}>
                  {/* Main content */}
                  {displayContent}

                  {/* Tool calls section - only for completed messages with tool calls */}
                  {message.status === 'completed' && message.toolCalls && message.toolCalls.length > 0 && (
                    <div style={{ marginTop: '12px', fontSize: '12px', color: '#9ca3af' }}>
                      <strong>Tools executed:</strong>
                      {message.toolCalls.map((tc, idx) => {
                        const params = Object.entries(tc.parameters)
                          .map(([key, value]) => `${key}: ${JSON.stringify(value)}`)
                          .join(", ");

                        return (
                          <div key={idx} style={{ marginTop: '4px' }}>
                            {tc.status === 'executing' && `⚡ Executing ${tc.tool}(${params})`}
                            {tc.status === 'completed' && (
                              <>
                                ✅ {tc.tool}({params})
                                {tc.executionTime && ` - ${tc.executionTime}ms`}
                                {tc.result && (
                                  <div style={{ marginLeft: '16px', fontSize: '11px' }}>
                                    Result: {tc.result}
                                  </div>
                                )}
                              </>
                            )}
                          </div>
                        );
                      })}
                    </div>
                  )}
                </div>
              </div>
            </div>
          );
        })}
      </div>
    );
  }

  return (
    <div
      style={{
        flex: 1,
        padding: '20px',
        overflowY: 'auto',
        display: 'flex',
        flexDirection: 'column',
        justifyContent: 'center',
        alignItems: 'center',
        textAlign: 'center'
      }}
    >
      <div style={{ maxWidth: '280px' }}>
        <h3 style={{
          margin: '0 0 12px 0',
          fontSize: '16px',
          fontWeight: '500',
          color: '#f3f4f6'
        }}>
          {title}
        </h3>
        <p style={{
          margin: 0,
          fontSize: '14px',
          color: '#9ca3af',
          lineHeight: '1.5'
        }}>
          {subtitle}
        </p>
      </div>
    </div>
  );
};

export default ChatMessages;
