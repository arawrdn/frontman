import React from 'react';
import { PaperPlaneIcon } from '@radix-ui/react-icons';
import SelectElementButton from './SelectElementButton';
import { SelectElement } from '../types/SelectElement';

interface ChatInputProps {
  message: string;
  onMessageChange: (message: string) => void;
  onSendMessage: () => void;
  placeholder?: string;
  modelName?: string;
  trialInfo?: string;
  onSettingsClick?: () => void;
  onElementSelected?: (element: SelectElement) => void;
  selectedElement?: SelectElement | null;
  onClearSelection?: () => void;
}

const ChatInput: React.FC<ChatInputProps> = ({
  message,
  onMessageChange,
  onSendMessage,
  placeholder = "Message the agent",
  modelName = "Claude Sonnet 4",
  trialInfo = "Trial mode: 0 / 20 messages available",
  onSettingsClick,
  onElementSelected,
  selectedElement,
  onClearSelection
}) => {
  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      onSendMessage();
    }
  };

  return (
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
            onChange={(e) => onMessageChange(e.target.value)}
            onKeyPress={handleKeyPress}
            placeholder={placeholder}
            style={{
              width: '100%',
              minHeight: '44px',
              maxHeight: '120px',
              padding: '12px 72px 12px 12px',
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
          <div style={{
            position: 'absolute',
            right: '8px',
            bottom: '8px',
            display: 'flex',
            gap: '4px'
          }}>
            {onElementSelected && (
              <SelectElementButton
                onElementSelected={onElementSelected}
                selectedElement={selectedElement}
                onClearSelection={onClearSelection}
                disabled={false}
              />
            )}
            <button
              onClick={onSendMessage}
              disabled={!message.trim()}
              style={{
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
        <span>{modelName}</span>
        <div style={{ display: 'flex', alignItems: 'center', gap: '16px' }}>
          <span>{trialInfo}</span>
          <button
            onClick={onSettingsClick}
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
  );
};

export default ChatInput;
