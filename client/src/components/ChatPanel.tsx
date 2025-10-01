import React from 'react';
import ChatHeader from './ChatHeader';
import ChatMessages from './ChatMessages';
import ChatTextLength from './ChatTextLength';
import ChatSelectedElement from './ChatSelectedElement';
import ChatInput from './ChatInput';
import { SelectElement } from '../types/SelectElement';

interface ChatPanelProps {
  message: string;
  onMessageChange: (message: string) => void;
  onSendMessage: () => void;
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
  onLearnMoreClick?: () => void;
  onSettingsClick?: () => void;
  onElementSelected?: (element: SelectElement) => void;
  selectedElement?: SelectElement | null;
  onClearSelection?: () => void;
}

const ChatPanel: React.FC<ChatPanelProps> = ({
  message,
  onMessageChange,
  onSendMessage,
  messages = [],
  onLearnMoreClick,
  onSettingsClick,
  onElementSelected,
  selectedElement,
  onClearSelection
}) => {
  return (
    <div
      data-widget-ui="true"
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
      <ChatHeader 
        onLearnMoreClick={onLearnMoreClick}
      />
      
      <ChatMessages 
        messages={messages}
      />
      
      <ChatSelectedElement
        selectedElement={selectedElement}
        onClearSelection={onClearSelection}
      />
      
      <ChatTextLength
        messages={messages}
      />
      
      <ChatInput
        message={message}
        onMessageChange={onMessageChange}
        onSendMessage={onSendMessage}
        onSettingsClick={onSettingsClick}
        onElementSelected={onElementSelected}
        selectedElement={selectedElement}
        onClearSelection={onClearSelection}
      />
    </div>
  );
};

export default ChatPanel;
