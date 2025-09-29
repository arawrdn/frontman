import React from 'react';
import { SelectElement } from '../types/SelectElement';

interface SelectedElementDisplayProps {
  selectedElement: SelectElement | null;
  onClear?: () => void;
}

const SelectedElementDisplay: React.FC<SelectedElementDisplayProps> = ({
  selectedElement,
  onClear
}) => {
  if (!selectedElement) return null;

  return (
    <div
      style={{
        position: 'fixed',
        bottom: '20px',
        left: '50%',
        transform: 'translateX(-50%)',
        zIndex: 1000000,
        backgroundColor: '#1f2937',
        color: 'white',
        padding: '12px 16px',
        borderRadius: '8px',
        boxShadow: '0 4px 12px rgba(0, 0, 0, 0.15)',
        border: '1px solid #10b981',
        display: 'flex',
        alignItems: 'center',
        gap: '12px',
        fontSize: '13px',
        fontWeight: '500',
        maxWidth: '600px',
        animation: 'slideUpFade 0.3s ease-out'
      }}
    >
      <div
        style={{
          width: '8px',
          height: '8px',
          backgroundColor: '#10b981',
          borderRadius: '50%'
        }}
      />
      
      <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '4px' }}>
        <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
          <span style={{ color: '#10b981', fontWeight: '600' }}>✓ Selected:</span>
          <code style={{ 
            backgroundColor: '#374151', 
            padding: '2px 6px', 
            borderRadius: '4px',
            fontSize: '12px',
            fontFamily: 'Monaco, Consolas, monospace',
            maxWidth: '300px',
            overflow: 'hidden',
            textOverflow: 'ellipsis',
            whiteSpace: 'nowrap',
            display: 'inline-block'
          }}>
            {selectedElement.selector}
          </code>
        </div>
        
        {selectedElement.reactComponent && (
          <div style={{ display: 'flex', alignItems: 'center', gap: '8px' }}>
            <span style={{ color: '#3b82f6', fontSize: '12px' }}>React:</span>
            <code style={{ 
              backgroundColor: '#1e3a8a', 
              color: '#93c5fd',
              padding: '2px 6px', 
              borderRadius: '4px',
              fontSize: '11px',
              fontFamily: 'Monaco, Consolas, monospace',
              maxWidth: '400px',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              whiteSpace: 'nowrap',
              display: 'inline-block'
            }}>
              {selectedElement.reactComponent.name.split(" ").reverse().slice(0, 3).reverse().join(" ")}
            </code>
          </div>
        )}
      </div>

      {onClear && (
        <button
          onClick={onClear}
          style={{
            background: 'none',
            border: '1px solid #6b7280',
            color: '#9ca3af',
            padding: '4px 8px',
            borderRadius: '4px',
            fontSize: '11px',
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
      
      <style>{`
        @keyframes slideUpFade {
          from { 
            opacity: 0; 
            transform: translateX(-50%) translateY(20px); 
          }
          to { 
            opacity: 1; 
            transform: translateX(-50%) translateY(0); 
          }
        }
      `}</style>
    </div>
  );
};

export default SelectedElementDisplay;
