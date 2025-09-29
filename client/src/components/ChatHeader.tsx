import React from 'react';

interface ChatHeaderProps {
  title?: string;
  subtitle?: string;
  learnMoreText?: string;
  onLearnMoreClick?: () => void;
}

const ChatHeader: React.FC<ChatHeaderProps> = ({
  title = "New Chat",
  subtitle = "Using your project's AGENTS.md.",
  learnMoreText = "Learn more",
  onLearnMoreClick
}) => {
  return (
    <div
      style={{
        padding: '20px',
        borderBottom: '1px solid #374151',
        backgroundColor: '#111827'
      }}
    >
      <h2 style={{
        margin: 0,
        fontSize: '18px',
        fontWeight: '600',
        color: '#f9fafb'
      }}>
        {title}
      </h2>
      <p style={{
        margin: '8px 0 0 0',
        fontSize: '14px',
        color: '#9ca3af',
        lineHeight: '1.4'
      }}>
        {subtitle}{' '}
        <span 
          style={{ color: '#60a5fa', cursor: 'pointer' }}
          onClick={onLearnMoreClick}
        >
          {learnMoreText}
        </span>
      </p>
    </div>
  );
};

export default ChatHeader;
