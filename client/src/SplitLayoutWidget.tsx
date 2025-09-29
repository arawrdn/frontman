import React, { useState, useEffect } from 'react';
import ChatPanel from './components/ChatPanel';
import ContentPanel from './components/ContentPanel';

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

  const handleLearnMoreClick = () => {
    console.log('Learn more clicked');
    // Add learn more functionality here
  };

  const handleSettingsClick = () => {
    console.log('Settings clicked');
    // Add settings functionality here
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
      <ChatPanel
        message={message}
        onMessageChange={setMessage}
        onSendMessage={handleSendMessage}
        onLearnMoreClick={handleLearnMoreClick}
        onSettingsClick={handleSettingsClick}
      />
      
      <ContentPanel
        iframeUrl={iframeUrl}
      />
    </div>
  );
};

export default SplitLayoutWidget;