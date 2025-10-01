import React from 'react';

interface ChatTextLengthProps {
  messages?: Array<{ id: string; content: string; sender: 'user' | 'assistant' }>;
}

const ChatTextLength: React.FC<ChatTextLengthProps> = ({
  messages = []
}) => {
  const totalCharacters = messages.reduce((total, message) => total + message.content.length, 0);
  const totalWords = messages.reduce((total, message) => {
    const words = message.content.trim().split(/\s+/).filter(word => word.length > 0);
    return total + words.length;
  }, 0);

  return (
    <div
      style={{
        padding: '16px 20px',
        borderTop: '1px solid #374151',
        backgroundColor: '#111827',
        fontSize: '12px',
        color: '#9ca3af',
        display: 'flex',
        justifyContent: 'space-between',
        alignItems: 'center'
      }}
    >
      <div style={{ display: 'flex', gap: '16px' }}>
        <span>
          <strong style={{ color: '#d1d5db' }}>{totalCharacters}</strong> characters
        </span>
        <span>
          <strong style={{ color: '#d1d5db' }}>{totalWords}</strong> words
        </span>
        <span>
          <strong style={{ color: '#d1d5db' }}>{messages.length}</strong> messages
        </span>
      </div>
      
      {totalCharacters > 0 && (
        <div style={{ fontSize: '11px', color: '#6b7280' }}>
          {totalCharacters > 10000 ? '🔥 Large conversation' : 
           totalCharacters > 5000 ? '📚 Medium conversation' : 
           totalCharacters > 1000 ? '💬 Active chat' : 
           '✨ Getting started'}
        </div>
      )}
    </div>
  );
};

export default ChatTextLength;
