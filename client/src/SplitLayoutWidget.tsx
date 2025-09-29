import React, { useState, useEffect } from 'react';
import { PaperPlaneIcon, ReloadIcon } from '@radix-ui/react-icons';

const SplitLayoutWidget: React.FC = () => {
  const [message, setMessage] = useState('');
  const [iframeUrl, setIframeUrl] = useState('');

  useEffect(() => {
    // Get the origin (protocol + hostname + port) without the path
    const currentUrl = new URL(window.location.href);
    const originUrl = `${currentUrl.protocol}//${currentUrl.host}`;
    setIframeUrl(originUrl);
  }, []);

  const handleSendMessage = () => {
    if (message.trim()) {
      console.log('Message sent:', message);
      // Here you would typically send the message to your chat service
      setMessage('');
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSendMessage();
    }
  };

  return (
    <div
      style={{
        display: 'flex',
        height: '100vh',
        width: '100vw',
        fontFamily: '-apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif',
        position: 'fixed',
        top: 0,
        left: 0,
        zIndex: 999999,
        backgroundColor: '#fff'
      }}
    >
      {/* Left Chat Panel */}
      <div
        style={{
          width: '400px',
          minWidth: '300px',
          maxWidth: '500px',
          backgroundColor: '#1f2937',
          color: 'white',
          display: 'flex',
          flexDirection: 'column',
          borderRight: '1px solid #374151'
        }}
      >
        {/* Header */}
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
            New Chat
          </h2>
          <p style={{
            margin: '8px 0 0 0',
            fontSize: '14px',
            color: '#9ca3af',
            lineHeight: '1.4'
          }}>
            Using your project's AGENTS.md.{' '}
            <span style={{ color: '#60a5fa', cursor: 'pointer' }}>Learn more</span>
          </p>
        </div>

        {/* Chat Messages Area */}
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
              What do you want to build?
            </h3>
            <p style={{
              margin: 0,
              fontSize: '14px',
              color: '#9ca3af',
              lineHeight: '1.5'
            }}>
              Type a message below to begin
            </p>
          </div>
        </div>

        {/* Input Area */}
        <div
          style={{
            padding: '20px',
            borderTop: '1px solid #374151'
          }}
        >
          <div
            style={{
              position: 'relative',
              display: 'flex',
              alignItems: 'flex-end',
              gap: '8px'
            }}
          >
            <div style={{ flex: 1, position: 'relative' }}>
              <textarea
                value={message}
                onChange={(e) => setMessage(e.target.value)}
                onKeyPress={handleKeyPress}
                placeholder="Message the agent"
                style={{
                  width: '100%',
                  minHeight: '44px',
                  maxHeight: '120px',
                  padding: '12px 40px 12px 12px',
                  backgroundColor: '#374151',
                  border: '1px solid #4b5563',
                  borderRadius: '8px',
                  color: 'white',
                  fontSize: '14px',
                  resize: 'none',
                  outline: 'none',
                  boxSizing: 'border-box',
                  fontFamily: 'inherit'
                }}
                rows={1}
              />
              <button
                onClick={handleSendMessage}
                disabled={!message.trim()}
                style={{
                  position: 'absolute',
                  right: '8px',
                  bottom: '8px',
                  width: '28px',
                  height: '28px',
                  backgroundColor: message.trim() ? '#3b82f6' : '#6b7280',
                  border: 'none',
                  borderRadius: '4px',
                  cursor: message.trim() ? 'pointer' : 'not-allowed',
                  display: 'flex',
                  alignItems: 'center',
                  justifyContent: 'center',
                  transition: 'background-color 0.2s'
                }}
              >
                <PaperPlaneIcon width={14} height={14} color="white" />
              </button>
            </div>
          </div>

          <div
            style={{
              marginTop: '12px',
              display: 'flex',
              justifyContent: 'space-between',
              alignItems: 'center',
              fontSize: '12px',
              color: '#6b7280'
            }}
          >
            <span>Claude Sonnet 4</span>
            <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
              <span>Trial mode: 0 / 20 messages available</span>
              <button
                style={{
                  background: 'none',
                  border: 'none',
                  color: '#6b7280',
                  cursor: 'pointer',
                  fontSize: '12px',
                  textDecoration: 'underline'
                }}
              >
                Settings
              </button>
            </div>
          </div>
        </div>
      </div>

      {/* Right Content Area - iframe */}
      <div
        style={{
          flex: 1,
          display: 'flex',
          flexDirection: 'column'
        }}
      >
        {/* Top Bar */}
        <div
          style={{
            height: '50px',
            backgroundColor: '#f8fafc',
            borderBottom: '1px solid #e2e8f0',
            display: 'flex',
            alignItems: 'center',
            justifyContent: 'space-between',
            padding: '0 16px'
          }}
        >
          <div
            style={{
              fontSize: '14px',
              color: '#64748b',
              display: 'flex',
              alignItems: 'center',
              gap: '8px'
            }}
          >
            <ReloadIcon width={16} height={16} />
            {iframeUrl}
          </div>

          <button
            onClick={() => {
              const iframe = document.querySelector('#main-content-iframe') as HTMLIFrameElement;
              if (iframe) {
                iframe.src = iframe.src; // Reload iframe
              }
            }}
            style={{
              padding: '6px 12px',
              backgroundColor: '#3b82f6',
              color: 'white',
              border: 'none',
              borderRadius: '4px',
              fontSize: '12px',
              cursor: 'pointer'
            }}
          >
            Reload
          </button>
        </div>

        {/* iframe */}
        <iframe
          id="main-content-iframe"
          src={iframeUrl}
          style={{
            flex: 1,
            border: 'none',
            width: '100%'
          }}
          title="Original Page Content"
        />
      </div>
    </div>
  );
};

export default SplitLayoutWidget;