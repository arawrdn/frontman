import React from 'react';
import { SelectElement } from '../types/SelectElement';

interface ChatSelectedElementProps {
  selectedElement?: SelectElement | null;
  onClearSelection?: () => void;
}

const ChatSelectedElement: React.FC<ChatSelectedElementProps> = ({
  selectedElement,
  onClearSelection
}) => {
  if (!selectedElement) {
    return (
      <div
        style={{
          padding: '16px 20px',
          borderTop: '1px solid #374151',
          backgroundColor: '#111827',
          fontSize: '12px',
          color: '#6b7280',
          textAlign: 'center'
        }}
      >
        No element selected
      </div>
    );
  }

  return (
    <div
      style={{
        padding: '16px 20px',
        borderTop: '1px solid #374151',
        backgroundColor: '#111827',
        fontSize: '12px',
        color: '#f3f4f6'
      }}
    >
      <div style={{ display: 'flex', alignItems: 'center', justifyContent: 'space-between', marginBottom: '8px' }}>
        <span style={{ color: '#10b981', fontWeight: '600', fontSize: '11px' }}>
          ✓ ELEMENT SELECTED
        </span>
        
        {onClearSelection && (
          <button
            onClick={onClearSelection}
            style={{
              background: 'none',
              border: '1px solid #6b7280',
              color: '#9ca3af',
              padding: '2px 6px',
              borderRadius: '3px',
              fontSize: '10px',
              cursor: 'pointer',
              transition: 'all 0.2s'
            }}
            onMouseEnter={(e) => {
              e.currentTarget.style.backgroundColor = '#374151';
              e.currentTarget.style.color = 'white';
            }}
            onMouseLeave={(e) => {
              e.currentTarget.style.backgroundColor = 'transparent';
              e.currentTarget.style.color = '#9ca3af';
            }}
          >
            Clear
          </button>
        )}
      </div>

      <div style={{ marginBottom: '6px' }}>
        <span style={{ color: '#9ca3af', fontSize: '11px' }}>Selector: </span>
        <code style={{ 
          backgroundColor: '#374151', 
          padding: '2px 4px', 
          borderRadius: '3px',
          fontSize: '11px',
          fontFamily: 'Monaco, Consolas, monospace',
          color: '#e5e7eb',
          wordBreak: 'break-all'
        }}>
          {selectedElement.selector}
        </code>
      </div>

      {selectedElement.reactComponent && (
        <div>
          <span style={{ color: '#9ca3af', fontSize: '11px' }}>React Component: </span>
          <code style={{ 
            backgroundColor: '#1e3a8a', 
            color: '#93c5fd',
            padding: '2px 4px', 
            borderRadius: '3px',
            fontSize: '11px',
            fontFamily: 'Monaco, Consolas, monospace',
            wordBreak: 'break-all'
          }}>
            {selectedElement.reactComponent.name.split(" ").reverse().slice(0, 3).reverse().join(" ")}
          </code>
        </div>
      )}
    </div>
  );
};

export default ChatSelectedElement;
